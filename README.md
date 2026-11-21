# KeepThat

KeepThat adds a short tooltip line to the materials worth keeping for endgame crafting or profession leveling, so you never sell what you'll need later. For WoW Forever and Classic Era.

## Quick start

Install it, then hover a material. Endgame materials show a line such as `KeepThat: Endgame: Blacksmithing (Shift)`, with "Endgame" in purple. Hold Shift to see which recipes use the item and how many you need. Type `/kt` for the settings.

## What it does

- **Endgame materials** (on by default): materials for raid and dungeon consumables, best-in-slot crafted gear, and other crafts that guides call essential at level 60. Materials that make them are marked too, for example Thorium Ore because it makes Thorium Bar for Arcanite Bar.
- **Leveling materials** (off by default): materials the common free leveling guides use to take a profession from 1 to 300. The count is what the guides need from your current skill to 300. When the guides differ, it is a range to keep on hand, such as `40-55`.
- KeepThat works on its own. Other addons only add to it.

### Tooltip line

Hover over a material and KeepThat adds one short line to its tooltip saying why it is worth keeping:

- `KeepThat: Endgame: Blacksmithing`, with "Endgame" in purple, for a material that endgame recipes use.
- `KeepThat: Leveling: Tailoring`, with "Leveling" in green, for a material you need to level a profession (only when leveling marks are on).
- `KeepThat: Endgame + Leveling: Blacksmithing`, each category word in its color, for an item marked in both.

While Shift is not held, the line ends with a grey `(Shift)` hint.

An item used by several professions lists them in the same line: up to two by name, then `+N` for the rest (`Endgame: Alchemy, Blacksmithing +2`). Items that are not marked get no line.

Hold **Shift** to see the details below the line:

- For an endgame material: the recipes that use it, with the quantity each needs (`Storm Gauntlets x2`). For a material that is marked because it makes another one, it says so (`Blacksmithing: used to make Thorium Bar for Arcanite Bar`).
- For a leveling material: the skill range, how many you still need, and how many you carry in your bags (`Tailoring 260-280: 40 needed, 12 in bags`). When the leveling guides disagree, the count is a range (`40-55 needed`).

Stock across characters: when any of your characters holds the item, the line ends with the total you own, such as `KeepThat: Leveling: Tailoring - 55 owned (Shift)`. The total covers every character on this realm and faction, counting bags, bank and mailbox, and never the guild bank or the account bank. Shift adds a short `Stock` block below the details: `This character: 20`, then one line per other character (`Bankmule: 30`), with `+3 more` after five lines.

Release Shift and the tooltip goes back to the single line. The line shows on item tooltips everywhere the game shows them: bags, bank, merchant, auction house, loot, mail, trade, chat item links and recipe reagents, and only once per tooltip. The colors can be changed in the settings, and "Tooltip line" turns the line off (it is on by default). The change takes effect on the next tooltip, without a reload.

Good to know: if something goes wrong while drawing the line (for example after a game patch), KeepThat turns the tooltip line off until the next reload instead of showing a Lua error, and `/kt log` names the failure.

### Loot toast (optional)

Turn on "Loot toast" in the settings and KeepThat shows a small pop-up when you loot a marked material: the item icon, its name and count (for example "Thorium Ore x5"), and the same colored line the tooltip shows. It fades in, stays about four seconds and fades out gently, ignores the mouse, and sits near the top center of the screen. The newest toast shows at that position and older ones glide up above it. Each item toasts once per session (login or reload); more of the same item looted while its toast is showing are added to its count, and pickups after it faded show nothing. At most three toasts show at once; the others wait and show as earlier ones fade. Only items you loot count: purchases, mail, trades, and crafting or quest rewards do not toast. The toast is off by default.

When a new toast appears it plays a sound: the auction house opening sound by default. In Appearance, pick None, one of ten game sounds (Auction open, Level up, Quest complete, Ready check, Raid warning, PvP queue ready, Murloc aggro, Bell toll for Alliance or Horde, Battle.net toast), or a sound pack registered with LibSharedMedia when another addon provides it. Choosing a different sound previews it once. Looting several items at once plays one sound, and adding to a toast's count is silent. The sound plays on the Master channel, so you hear it with game sound effects off; choose Sound effects to follow that setting instead. KeepThat ships no sound files; if a chosen sound pack is removed, the default plays.

### Icon mask

Turn on **Icon mask** to tint the icons of marked materials:
- Endgame materials are tinted purple, and leveling materials green. You can change both colors.
- An item that is both uses the endgame color.
- The tint is light, so the icon, its stack count and its quality border stay readable.

It is off by default.

**Show marks in** picks where the tint appears: bags, bank and the merchant window (including its buyback tab, so you can spot a material you sold by mistake). All three are on by default. The auction house, mail, loot and trade windows are not tinted in this version; the tooltip line still shows there.

Changing a color or a setting updates the icons already on screen, with no reload. When a marked item leaves a slot, the slot loses its tint.

The tint works in:
- Blizzard's default bags and bank, on both clients.
- Baganator, Bagnon and EllesmereUI Bags, on WoW Forever.

### Integrations page

The page lists each supported addon with a **Use this integration** toggle and a status line:
- not detected;
- detected and working;
- turned off;
- failed, with the reason.

Each integration is detected automatically. Turning one off affects only that addon.

On Classic Era, the page says integrations are not yet available there. The icon mask still works in Blizzard's bags and bank.

### Good to know about bags

- If a bag addon changes in a way KeepThat does not expect, KeepThat turns that integration off for the session. The bag addon keeps working, and you see no error. `/kt log` names the integration and the reason.
- Bagnon and Baganator buttons that were built before KeepThat started show no tint until a `/reload`. This normally doesn't happen, because KeepThat starts at login, before any bag is opened.

### Auctionator shopping lists (WoW Forever, optional)

With Auctionator installed, KeepThat can turn the materials you still need into an Auctionator shopping list, so buying them takes one search instead of many. Pick a profession and either endgame or leveling materials and export: Auctionator gets a list named "KeepThat: <Profession> <Category>" (for example "KeepThat: Tailoring Leveling") with one exact search per material you have left turned on.

- Leveling lists only include what you still need from your current skill. When a guide gives a count, a material you already own enough of across your characters (same realm and faction) is left out, and the rest carry the difference as the quantity.
- Exporting the same profession and category again replaces that KeepThat list. Your own Auctionator lists are never touched.
- Without Auctionator, or with an Auctionator version whose interface has changed, the export control is disabled and says why. Nothing errors.
- It can be turned off on the Integrations page. On Classic Era integrations are not yet available.

### DFL Profession Journal (WoW Forever, optional)

When DFL Profession Journal is installed, its leveling route counts as one more source for leveling materials, next to the built-in guides:

- Materials its route uses become leveling materials, and its counts take part in the range shown. If it needs more of a material from your current skill than any built-in guide, the top of the range is its count, and the Shift details name "DFL Profession Journal".
- KeepThat reads Profession Journal's own route each session and never copies or saves it.
- If Profession Journal's data cannot be read or has an unexpected shape (for example after one of its updates), KeepThat quietly uses only the built-in guides, shows no error, and the debug report (`/kt log`) records why.
- It can be turned off on the Integrations page.

### Good to know about integrations

- The Auctionator list buys only what your realm-and-faction total does not cover: what you own across your characters' bags, bank and mailbox is subtracted from the quantity.
- Profession Journal's live plan (which changes with your bags and prices) is not used; KeepThat uses its fixed route for your faction, so the counts stay steady.
- Turning Profession Journal off on the Integrations page removes the materials only its route uses from Materials, `/kt find`, the leveling counts and the Auctionator lists at once; turning it on brings them back. No reload needed. Stock keeps counting them either way.
- Where Profession Journal gives no count for the steps still ahead, KeepThat shows no count rather than claiming you have enough.

### Stock across characters

KeepThat remembers what each of your characters has in bags, bank and mailbox and adds it up for the tooltip, the Materials page and the Auctionator list. Nothing needs setting up: log in on a character, open its bank and its mailbox once, and it counts from then on. The guild bank and the account bank are never counted.

- `/kt status stock` shows `Stock: 3 characters on <Realm> (<Faction>).`, then one line per character whose bank or mailbox is not counted (`<Name>: bank not counted.`, `mailbox not counted.` or `bank and mailbox not counted.`), or `Every bank and mailbox is counted.`
- While any bank or mailbox is not counted, the item page hides "Still to get", because the total could be too low.
- Login reminder (Home, on by default; `/kt set stock.reminder off` turns it off): once per session, at login and after a `/reload`, a chat line such as `KeepThat: 2 characters have a bank or mailbox not counted. /kt status stock lists them.` It stays silent when every bank and mailbox is counted.

Good to know about stock:

- Only characters on the same realm and faction are counted.
- WoW Forever has no realm names, so "same realm" means the same ruleset (PvE, PvP, RP, RP-PvP or Hardcore). Updating from 0.4.5 or earlier, each character's stock is shared with its alts again once that character logs in.
- A character counts after it logs in once with KeepThat. Its bags count right away; its bank and mailbox count once you open them.
- Mail on its way to another character is not counted until it arrives.
- Closing the bank or mailbox right after moving something can leave it "not counted" until your next visit, rather than counting a stack twice.
- With Profession Journal, the materials only its route uses are counted too, from the next time each bank and mailbox is opened.
- Only the mail the game shows is counted, so a mailbox with more than 50 mails can be short.
- Cash-on-delivery items count before they are paid for.
- Characters not seen for 90 days, and bank or mailbox counts older than 90 days, are left out. A renamed or deleted character drops out the same way.
- Two characters leveling the same profession both count the same stock.

## Settings

For the reusable layout and interaction decisions, see [DESIGN.md](DESIGN.md).

Open the settings with `/kt`, or under Options > AddOns > KeepThat. In the game's Options window, Materials only has an **Open KeepThat** button, which closes Options and opens the KeepThat window on Materials; the full material list lives there. Changes apply on the next tooltip or bag refresh; no reload needed. Settings are saved for your whole account by default.

- **Home**: choose what to mark and where to show it. Endgame and tooltips start on; leveling, loot toasts and icon tint start off. Choose bags, bank and merchant for icon tint. **Login reminder** (on by default) tells you at login when a character's bank or mailbox is not counted in your stock.
- **Materials**: profession, then material, following what you mark on Home. A small square in each tint color shows whether a material is for endgame, leveling or both. Each material page shows its icon and name (in the item's quality color), "Keep for endgame" / "Keep for leveling", what it is used for, how many you still need, every recipe that uses it, your stock ("Your stock": `55 owned - 20 on this character, 35 on your other characters`, then a line per character such as `Bankmule: 30 in the bank (3 days ago)`), and a button that copies its Wowhead link. Search by name at the top; Clear search works from any profession page. Each profession page can export its endgame or leveling list to Auctionator. Every profession starts collapsed each time the settings open. Materials an update adds start on; the ones you turned off stay off.
- **Integrations**: Baganator, Bagnon, EllesmereUI Bags, Auctionator and DFL Profession Journal, each with whether it is detected and working, and a toggle. Integrations are not yet available on Classic Era.
- **Appearance**: category colors, icon tint strength, independent Background opacity and Text and icon opacity (0–100), Scale (50–200), toast Sound and Sound channel, Preview, Move, Lock position and Reset position. Move saves only on Done (or right-click); Cancel or Escape restores the start. Reset affects only the anchor. Black surfaces and accents disappear at background opacity 0. Older whole-toast opacity migrates to both layers without changing brightness.
- **Advanced**: use separate settings for this character (switches to a profile named after the character, and back to the shared Default profile), debug recording, and a button for the debug report. On WoW Forever, a character that used its own settings before 0.4.3 keeps them, including after turning "This character" off and on.
- **About**: the version and the commands.

The standalone settings window opens at a compact 600×460 and remains resizable. Controls use compact widths while explanations wrap across the page. Each page explains its purpose and whose settings it changes. Appearance groups category colors, icon tint, loot toast dimming, position and separate toast/tooltip/tint previews; disabled controls explain the prerequisite without discarding their values. Integration rows describe what each addon contributes as well as its detected status.

Search Materials by part of an item name and press Enter. Clear search works from profession pages too. Search lasts only for the session. The page content explains whether settings are shared or specific to this character; scope changes retain both profiles without copying them.

## Commands

| Command | What it does |
| --- | --- |
| `/kt find <name>` | Finds materials by client or English name; one match opens its page, several open Materials filtered to the name. |
| `/kt` | Opens the settings on the Home page. |
| `/kt settings [page]` | Opens Home, Materials, Integrations, Appearance, Advanced or About; page names are case insensitive. |
| `/kt help [topic]` | Lists commands or targeted appearance, diagnostics or domain help. |
| `/kt status [topic]` | Reports scope, effective public values and integration availability; accepts the same topics as help. |
| `/kt get <key>` | Reads an allowlisted setting without writing. |
| `/kt set <key> <value>` | Validates and updates one public setting, with one acknowledgement. |
| `/kt status stock` | Lists the characters counted in your stock and which banks or mailboxes are not counted yet. |
| `/kt help stock` | Explains the stock commands and settings. |
| `/kt preview [kind]` | Lists kinds, or shows one isolated toast, tooltip, tint or copy sample. |
| `/kt log clear` | Confirms before clearing recorded diagnostics and failures; retains gameplay data and settings. |
| `/kt test toast` | Shows one sample loot toast. |
| `/kt test tooltip` | Shows a random real material tooltip with sample profession skills and bag counts; hold Shift for details. |
| `/kt test copy` | Shows the copy-link box. |
| `/kt demo` | Shows three synthetic loot toasts, a private mouse tooltip and an isolated tint sample even with features off. Repeating replaces samples; real loot state remains separate. |
| `/kt debug on` | Starts recording diagnostics. |
| `/kt debug off` | Stops recording. |
| `/kt log` | Opens a window with the debug report (every setting, each integration's state, failures and recorded lines) that you can select and copy. |
| `/kt probe` | Opens a window with a report on the game's API (for bug reports). |
| `/kt probe hover` | The same for the item under the mouse. |
| `/kt probe path <name>` | Describes one global table, e.g. `DFLProfessionJournalNS.API`. |

Public keys use the active profile. `toast` (off), `tooltip` (on), `stock.reminder` (on) and `appearance.toast.locked` (off) accept `on` or `off`. `appearance.toast.background-opacity` and `appearance.toast.text-opacity` accept whole numbers 0–100 (new installs: 100); `appearance.toast.scale` accepts whole numbers 50–200 (default: 100). For example: `/kt set appearance.toast.text-opacity 80`. Existing saved values take precedence. No SavedVariables paths, executable input or trailing arguments are accepted. Existing command names remain; no new aliases are introduced. Toasts fade after four seconds; the tooltip sample expires after fifteen seconds and the tint after four. Samples do not consume real loot deduplication or trigger integrations.

## Where the data comes from

- Recipes and reagents: each client's own game data (see `THIRD_PARTY.md` for the builds).
- Leveling routes: wow-professions.com and Wowhead for Classic Era; Metabot and RankedBoost for WoW Forever; DFL Profession Journal when it is installed (read in game, never copied).
- Endgame lists: curated for KeepThat. WoW Forever uses the Classic Era lists for now.

## For developers

- `make test` runs the Lua and Python tests; `make check` runs the TOC, embeds and version checks.
- `make catalog` regenerates `KeepThat/Data/` from the DB2 tables and `tools/routes/`, `tools/endgame/`.
- See `CLAUDE.md` for conventions and `docs/` for publishing, localization, the test plan and the client contracts.

## License

MIT. See `LICENSE` and `THIRD_PARTY.md`.
