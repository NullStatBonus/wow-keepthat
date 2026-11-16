## Why

KeepThat counts only the current character's bags and, once the bank has been opened this session, its bank. Players keep materials on several characters, so "Still to get", the Shift counts and the Auctionator shopping list overstate what is missing and lead to buying what they already own.

## What Changes

- KeepThat records the stock of every catalog and route material per character: bags, bank and mailbox. The guild bank is never counted, and mail on its way to another character is not tracked. Records are saved for the whole account. Only characters on the current realm and faction count.
- Everything is shown from the current character's view: "this character" and "your other characters". No character is designated main or alt.
- **Tooltip:** the always-on line gains a short total (`- 55 owned`), left out at 0. Shift keeps `40 needed, 12 in bags` and adds a Stock block listing the stock per character: this character first, at most 5 rows, then `+N more`.
- **Materials item page:** "Your stock" shows the total split between this character and the others, then one line per character holding any, with an age for other characters. Both prompts to open the bank are removed.
- **Need:** the current character's leveling need is reduced by the realm-and-faction total. "Still to get" is hidden while any counted character has a bank or mailbox not yet counted. The Auctionator list uses the counted total.
- **Login reminder:** at login or reload, one chat line without names says how many characters have a bank or mailbox not counted yet. It is silent when nothing is missing. It is the only prompt to open banks and mailboxes. The new `/kt status stock` names which ones.
- **Expiry:** a character not seen for 90 days or more is left out, and its record is deleted at the next login. A bank or mailbox count older than 90 days is dropped. Renamed or deleted characters drop out the same way; there is no manual forget control.
- No dependency on Syndicator, Altoholic or other inventory addons. KeepThat follows Syndicator's pattern for reading bags, the bank and the mailbox, and Forever uses the modern bank APIs.
- No new settings pages or sub-menu entries. The only new row is a "Login reminder" checkbox on Home, the same setting as `/kt set stock.reminder on|off`.

## Capabilities

### New Capabilities
- `character-stock`: per-character stock records (bags, bank, mailbox), their scope (realm and faction), saving and expiry, the realm-and-faction total, and the login reminder.

### Modified Capabilities
- `material-tooltip`: "One short line per marked item" gains the owned total. "Details while Shift is held" gains the total and the per-character stock block.
- `settings`: "Material stock on its page" shows stock across characters. "still to get" uses the realm-and-faction total and is hidden while counts are incomplete.
- `auctionator-export`: "Only what is still needed" uses the realm-and-faction total instead of the bags count.
- `slash-interface`: `/kt status` accepts the `stock` topic.

## Impact

- New `KeepThat/Core/Adapter_Stock.lua` (bank and mailbox reads, character identity, clock) and a plain-Lua `KeepThat/Model/Stock.lua` (records, totals, expiry). The stock logic for reading and saving goes in a small UI-free module. Both TOCs need the new files.
- Changes: `Options/Options.lua` (Your stock, How many), `Model/Wording.lua` and `UI/Tooltip.lua` (line and Shift block), `Integrations/Auctionator.lua` (quantity), `Core/Slash.lua` and `Core/Presentation.lua` (`status stock`), `Core/Defaults.lua` (`global.stock`), `Core/Addon.lua` (events, login reminder), `Debug/Log.lua` (report lists stock state).
- Saved data: a new versioned `KeepThatDB.global.stock`. Existing settings are untouched.
- Docs: README (stock, Good to know, the Auctionator lead), `docs/test-plan.md`, `docs/contracts.md` (bank and mailbox calls per client), `docs/listing.md`.
- Release: 0.3.0.
