# Proposal

## Why

The 2026-11-20 bug review found five ways the cross-character stock can be wrong or misreported: double counts, missing items, and messages that claim more than KeepThat knows. This is the second small patch from that review (release 0.4.6). Most fixes are proven by unit tests; four need an in-game check.

## What Changes

- **Bank tab list (review #3).** On a client with bank tabs, a tab entry that has no ID used to be skipped silently. The shortened list then deleted that tab's saved count.
  - The tab's ID now comes from the game's tab enum instead.
  - If it is still unknown, the whole list counts as unread, and the saved bank is kept.
- **Late changes after closing (review #6).** The game can report a bank or mailbox change just after the window closes, for example after taking an item and pressing Escape at once.
  - Today that report is ignored. The old bank or mail record stays while the bags gain the item, so the item is counted twice.
  - Now a report that arrives shortly after closing makes the affected bank container or the mailbox "not counted" until it is opened again.
- **Profession Journal materials (review #7).** Materials used only by Profession Journal's route are now recorded in stock. Their totals and the Auctionator list then include what alts hold.
- **"None" while the stock is incomplete (review #8).** A material page says "None on any of your characters." only when every bank and mailbox is counted. Otherwise it says "None counted yet."
- **Sources the client cannot read (review #19).**
  - At login, a bank or mailbox that this client cannot read is recorded as unavailable, so the login reminder doesn't ask for it.
  - `/kt status stock` no longer claims everything is counted when a source can't be read.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `character-stock`:
  - "Stock recorded per character" now includes Profession Journal's route materials.
  - "Sources read while open" covers a change reported shortly after a window closes.
- `settings`: "Material stock on its page" says "None counted yet." when nobody holds the material and the total is incomplete.

## Impact

- **Code:**
  - `Core/Adapter_Stock.lua` (`BankIDs`)
  - `Core/Stock.lua` (`Tracked`, close handling, login availability)
  - `Options/Options.lua` (`stockLine`)
  - `Core/Slash.lua` (`StockStatus`)
  - `Locales/enUS.lua`, if it lists strings
- **Tests:** `test_adapter_stock`, `test_stock_recorder`, `test_options`, `test_slash`.
- **Docs:**
  - `README.md` (stock "Good to know")
  - `docs/test-plan.md` (section 12, four checks)
  - `docs/contracts.md` (the tab-ID fallback and the window after closing)
- **Saved data:** no format change.
- **Release:** patch, 0.4.6.
