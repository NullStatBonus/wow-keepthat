# Design

## Context

See proposal.md for motivation. Current state:

- Stock is read live with `A.ItemCount` (`C_Item.GetItemCount` / `GetItemCount`). `Options.Stock` derives the bank as total minus bags, and trusts a bank 0 only after `BANKFRAME_OPENED` in this session (`Options.bankSeen`). Nothing is saved.
- `KeepThatDB` holds the profile (settings) and `global.log`. AceDB is already loaded.
- Game calls live in `Core/Adapter*.lua`, are guarded and wrapped in pcall, and give nil when missing. Logic in `Model/` is plain Lua, so tests run under luajit.
- KeepThat follows Syndicator's pattern (BagBrother and DataStore were read as well, 2026-11-16). That source shows:
  - The Era bank is `BANK_CONTAINER` (-1) plus bank bags `NUM_BAG_SLOTS+1 .. NUM_BAG_SLOTS+NUM_BANKBAGSLOTS` (5-10).
  - Forever (16001) uses the modern APIs: character bank tabs (`Enum.BagIndex.CharacterBankTab_1..`, `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`). KeepThat takes the same path, chosen by the APIs existing rather than by build number.
  - Mail is read with `GetInboxNumItems`, `GetInboxHeaderInfo` and `GetInboxItem(i, a)`, which returns itemID second and count fourth.
  - Each reading replaces a source whole, so a stack moved between sources is never counted twice.

## Goals / Non-Goals

**Goals:**
- One plain-Lua model that every surface uses for totals, completeness and per-character rows: the tooltip line, Shift, the item page, Auctionator, the reminder and `/kt status stock`.
- Bank and mailbox reads that choose a code path by which functions exist, never by client name.
- Saved data that stays small (catalog and route materials only) and is versioned.

**Non-Goals:**
- Tracking mail on its way to another character, auction listings, or equipped items.
- Reading another character's data from other addons.
- Identifying renamed or transferred characters.
- The account (warband) bank, which Syndicator reads separately. Like the guild bank it belongs to no character, so it is left out.

## Decisions

### D1. Data model in `KeepThatDB.global.stock`
```
global.stock = { version = 1, realms = {
  [realm] = { [faction] = { [name] = {
      seen = <time()>,
      bags = { expected = { bagID, ... }, c = { [bagID] = { t = <time()>, items = { [itemID] = n } } } },
      bank = nil | { unavailable = true } | { expected = { bagID, ... }, c = { [bagID] = { t, items } } },
      mail = nil | { unavailable = true } | { t, items },
  } } } } }
```
- Each container (a bag, bank bag or tab, or the whole inbox) is committed on its own with its own `t`, as in Syndicator.
- A source is **counted** only when every container the source expects has a record. Each source saves the container IDs it expects as `expected` (bags at login, the bank at the last bank visit). A source's age is its oldest container's `t`, so one failing bag can't be refreshed by its neighbours.
- `nil` means not counted. `unavailable` means the client cannot read that source.
- Items with a count of 0 are left out.
- The faction level keeps the realm-and-faction scope a single table lookup. Records for other factions and realms stay on disk but are never shown.
- *Alternative:* a flat `"Name-Realm"` key with a faction field. It needs a full scan per lookup and has no clearer benefit.
- `version` lets a later change migrate or reset the area without touching settings.

### D2. Identity and clock (`Core/Adapter_Stock.lua`)
- `A.PlayerIdentity()` returns `name, realm, faction`. It reads `UnitFullName("player")` and falls back to `UnitName` plus `GetNormalizedRealmName()`. Faction comes from `UnitFactionGroup("player")`.
- If any part is nil, nothing is recorded this session. The debug report notes it.
- `A.Clock()` returns `time()`. The existing `A.Now()` (`GetTime`, uptime) does not persist across sessions, so it is not used here.
- The model treats a clock earlier than a saved `t` as `t`.

### D3. What is recorded
- The set of tracked IDs is every item in the active catalog's endgame and leveling tables plus every route material, built once per session from `ns.Context`. It does not depend on settings.
- Profession Journal's extra materials are not recorded. They show from the current character's live count only, as today.

### D4. Reading sources (Syndicator's pattern)
- **Containers:**
  - The bags are the backpack through the last equipped bag (`NUM_TOTAL_EQUIPPED_BAG_SLOTS` or `NUM_BAG_SLOTS`), which covers the reagent bag where one exists.
  - The bank uses the modern character tabs when both `Enum.BagIndex.CharacterBankTab_1` and `C_Bank.FetchPurchasedBankTabData` exist, taking the tab IDs that call returns for `Enum.BankType.Character`. Forever takes this path. Otherwise it uses `BANK_CONTAINER` plus `NUM_BAG_SLOTS+1 .. +NUM_BANKBAGSLOTS`, then `REAGENTBANK_CONTAINER` if defined.
  - The keyring, the guild bank and the account bank are never included.
  - The current lists are enumerated at login and at each bank open. This list replaces `A.BagLocation` for enumeration, and `BagLocation` stays for the overlay.
- **Events, all into one pending set processed once on the next frame (`C_Timer.After(0)`):**
  - `BAG_UPDATE(bagID)` queues the bag if it is a player bag. It queues a bank bag only while `bankOpen`.
  - `PLAYERBANKSLOTS_CHANGED(slot)`, while `bankOpen`: on the modern path its argument is a tab index, mapped to that tab's bag ID. On the classic path it queues `BANK_CONTAINER`.
  - `BAG_CONTAINER_UPDATE` (a bag swapped) and, where they exist, `PLAYERBANKBAGSLOTS_CHANGED`, `BANK_TABS_CHANGED` and `BANK_TAB_SETTINGS_UPDATED` (a bag or tab bought) re-enumerate the lists. While the bank is open, they queue every bank container again.
  - `BANKFRAME_OPENED` sets `bankOpen`, re-enumerates and queues every bank container. `BANKFRAME_CLOSED` clears `bankOpen` and drops queued bank containers.
  - `MAIL_INBOX_UPDATE` queues one inbox rescan, and `MAIL_CLOSED` drops it.
  - When the pending set runs, it checks again that the bank or mailbox is still open before reading it, as Syndicator does, so a closed window never overwrites a record.
- **Reading a container:**
  - For each slot from `C_Container.GetContainerNumSlots`, with legacy globals as a fallback, a slot is empty when `C_Container.GetContainerItemInfo` returns nil and `GetContainerItemID` gives nothing.
  - An occupied slot needs both an `itemID` and a `stackCount`. Only the ID and count are used, so item data never has to be cached.
  - If a call errors, or an occupied slot lacks its ID or count, the read fails. The container's previous record stays, the failure is logged once per session, and the next event retries.
- **Reading the inbox:**
  - `GetInboxNumItems()` gives the shown mails. For each one, `GetInboxHeaderInfo(i)` must return a header, and its `hasItem` return marks mails with attachments.
  - Attachments run `1 .. (ATTACHMENTS_MAX_RECEIVE or ATTACHMENTS_MAX or 16)` through `GetInboxItem(i, a)`, which returns itemID second and count fourth. If the name is set but the ID is nil, the ID is parsed from `GetInboxItemLink`.
  - A missing header, or an attachment with a name but no ID and no link, fails the rescan, and the previous record stays.
- **Unavailable:** if neither bank path exists, or `GetInboxNumItems` is missing, that source is recorded as `{ unavailable = true }`. A bank path that exists but whose tab list cannot be read is a failed read, not unavailable: the saved bank is kept.
- *Alternative considered:* the bank as live `GetItemCount(id, true)` minus bags. Rejected because it can't separate the bank from mail and can't detect a failed read.

### D5. The current character's live view
- For the current character, the bags count in totals and Shift is live (`A.ItemCount(id)`), so it can never lag behind a fresh loot.
- The current character's bank and mail come from its records.
- This retires `Options.bankSeen` and the "open your bank" wording.

### D6. Model (`Model/Stock.lua`, plain Lua)
- `Stock.Scope(db, realm, faction)` gives the characters in scope.
- `Stock.Prune(db, now)` deletes characters whose `seen` is 90 or more days old. It runs once at login, after the current character's `seen` is updated.
- `Stock.Source(rec, now)` gives the counted items, or "not counted" when missing or older than 90 days, or "unavailable".
- `Stock.Total(scope, id, now, selfName, selfBags)` returns `total, complete, rows`.
  - Each row is `{ name, self, bags, bank, mail, oldest }`.
  - Sort order: self first, then by count descending, then by name.
  - `complete` is false when any character in scope has bags, bank or mail not counted, or when this character's live bag count is unknown (nil). `unavailable` never makes it false. An unknown count is never treated as 0.
- `Stock.Missing(scope, now)` lists `{ name, bank = bool, mail = bool }` for the reminder and `/kt status stock`.
- `Stock.Age(seconds)` returns a bucket and a number, which the UI words with singular and plural forms.

### D7. Surfaces
- **Tooltip line:** `Wording.ColoredLine` gains `opts.owned`. When owned is more than 0, it appends `L[" - %d owned"]` (grey dash, neutral count) before the `(Shift)` hint. It is a whole localized template.
- **Shift:** the need row keeps `"%s needed, %d in bags"`. A new block follows the category blocks: a grey `  Stock` row of kind `line` with inline color, since an unknown kind renders white, then `    This character: %d` and `    %s: %d` rows, up to 5, then `    +%d more`. Indentation uses the existing 2 and 4 spaces.
- **Item page:** the "Your stock" section is rebuilt from `Stock.Total`:
  - A summary line, then all holders in a single multi-line `description` whose `name` is a function. The existing recipe and "other professions" rows already work this way. The cached options tree therefore never freezes the row count.
  - Other characters' lines end with a grey age, `(3 days ago)`, and this character's line has none.
  - When a stock record changes while the window is open, the recorder calls `Options.NotifyChange()`.
  - The `stockHelp` line and the `(open your bank to count it)` branch are removed.
  - The `toGet` row's `hidden` also covers `not complete`. The existing "You have enough." and "Still to get: %d" / "%d-%d" strings are kept.
  - Rows are Ace `description` widgets inside the existing section. No new groups.
- **Auctionator:** `carried` becomes the realm-and-faction total, used even when incomplete.
- **Home:** a `profileToggle("stockReminder", L["Login reminder"], L["Remind you at login when a character's bank or mailbox is not counted."])` row after Loot toast.
  - `profileToggle` gains an optional public key argument, so it calls `P.Set("stock.reminder", ...)` rather than looking up `P.keys[storage]`.
  - `stockReminder = true` goes in profile defaults.
  - The "All displays are off" condition is unchanged.
- **Slash:**
  - `P.keys` gets `entry("stock.reminder", "stockReminder", "boolean", nil, nil, true)`.
  - `/kt help appearance`'s key list gains `stock.reminder (on|off)`.
  - `status` accepts the `stock` topic, which prints a scope line and then one line per missing source.
- **Reminder:** printed once per session at `PLAYER_LOGIN`, after the first bags read. A `/reload` is a new session, so it prints again. KeepThat does not tell a login from a reload, because that brings no benefit.
- **Debug report:** lists the stock version, the characters in scope, the missing sources, which sources are unavailable, and the reminder setting.

## Risks / Trade-offs

- [The bank path follows Syndicator; Forever's tabs are not yet checked in game] → the bank list is chosen by the APIs existing, and tests cover both paths. The Forever in-game check confirms the counts.
- [More than 50 mails: the inbox shows only what the server sends] → count what is shown and treat the mailbox as counted. Noted under Good to know.
- [Cash-on-delivery mail counts as owned before it's paid] → accepted, the same as Syndicator. Noted under Good to know.
- [An incomplete total stays incomplete until every character in scope opens its bank and mailbox, so "Still to get" stays hidden] → the user chose this. The reminder and `/kt status stock` say how to fix it.
- [Two characters leveling the same profession both count the same stock] → accepted and noted.
- [A renamed or deleted character lingers for up to 90 days] → accepted, as the user chose.
- [Saved size grows with characters × materials] → only IDs with a count above 0 are stored, and at most a few hundred catalog items exist.
- [A `BAG_UPDATE` burst while looting] → the pending set gives one read per changed bag per frame.

## Migration Plan

- A new `global.stock` is created empty by the recorder at the first login. It is not in the AceDB defaults, whose recursive merge would add `realms` to another version's data. Settings are untouched.
- Each character gains a record on its next login. No upgrade step is needed.
- Rollback: an older KeepThat ignores `global.stock`.
- A `version` other than 1, written by a newer KeepThat, is left untouched and not used. Stock then shows as unknown, and nothing is overwritten.
