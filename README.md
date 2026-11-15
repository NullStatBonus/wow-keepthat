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
- For a leveling material: the skill range, how many you still need, and how many you have in your bags (`Tailoring 260-280: 40 needed, 12 in bags`). When the leveling guides disagree, the count is a range (`40-55 needed`).

Release Shift and the tooltip goes back to the single line. The line shows on item tooltips everywhere the game shows them: bags, bank, merchant, auction house, loot, mail, trade, chat item links and recipe reagents, and only once per tooltip. The colors can be changed in the settings, and "Tooltip line" turns the line off (it is on by default). The change takes effect on the next tooltip, without a reload.

Good to know: if something goes wrong while drawing the line (for example after a game patch), KeepThat turns the tooltip line off until the next reload instead of showing a Lua error, and `/kt log` names the failure. The bag count covers your bags, not the bank.

### Loot toast (optional)

Turn on "Loot toast" in the settings and KeepThat shows a small pop-up when you loot a marked material: the item icon, its name and count (for example "Thorium Ore x5"), and the same colored line the tooltip shows. It fades after a few seconds, ignores the mouse, and sits near the top center of the screen. Each item toasts once per session (login or reload); more of the same item looted while its toast is showing are added to its count, and pickups after it faded show nothing. At most three toasts show at once; the others wait and show as earlier ones fade. Only items you loot count: purchases, mail, trades, and crafting or quest rewards do not toast. The toast is off by default.

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

- Leveling lists only include what you still need from your current skill. When a guide gives a count, a material you already carry enough of is left out, and the rest carry the difference as the quantity.
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

- The Auctionator quantity uses what you carry in your bags. (Lead: confirm once `ns.Adapter.ItemCount` exists, and whether it counts the bank.)
- Profession Journal's live plan (which changes with your bags and prices) is not used; KeepThat uses its fixed route for your faction, so the counts stay steady.

## Settings

Open the settings with `/kt`, or under Options > AddOns > KeepThat. Changes apply on the next tooltip or bag refresh; no reload needed. Settings are saved for your whole account by default.

- **Home**: turn endgame materials (on by default) and leveling materials (off by default) on or off; turn the tooltip line (on), loot toast (off) and icon mask (off) on or off; move the loot toasts (drag the placeholder, right-click when done) or reset their position; pick the endgame color (purple) and leveling color (green); choose where the mask shows with "Show marks in" (bags, bank and merchant, all on by default).
- **Materials**: profession, then material, following what you mark on Home. A small square in each tint color shows whether a material is for endgame, leveling or both. Each material page shows its icon and name (in the item's quality color), "Keep for endgame" / "Keep for leveling", what it is used for, how many you still need, every recipe that uses it, your stock, and a button that copies its Wowhead link. Search by name at the top; Clear search works from any profession page. Each profession page can export its endgame or leveling list to Auctionator. Materials an update adds start on; the ones you turned off stay off.
- **Integrations**: Baganator, Bagnon, EllesmereUI Bags, Auctionator and DFL Profession Journal, each with whether it is detected and working, and a toggle. Integrations are not yet available on Classic Era.
- **Advanced**: use separate settings for this character (switches to a profile named after the character, and back to the shared Default profile), debug recording, and a button for the debug report.
- **About**: the version and the commands.

Search either materials page by part of an item name and press Enter. Clear the box to show all materials. Searches are separate for each category and last only for the session.

## Commands

| Command | What it does |
| --- | --- |
| `/kt find <name>` | Finds materials by client or English name; one match opens its page, several list up to ten paths. |
| `/kt` | Opens the settings on the Home page. |
| `/kt test toast` | Shows one sample loot toast. |
| `/kt test tooltip` | Shows a sample tooltip (Arcanite Bar); hold Shift for the details. |
| `/kt test copy` | Shows the copy-link box. |
| `/kt demo` | Shows three sample loot toasts and a sample tooltip (Arcanite Bar), whatever the settings say, to check the look. |
| `/kt debug on` | Starts recording diagnostics. |
| `/kt debug off` | Stops recording. |
| `/kt log` | Opens a window with the debug report (every setting, each integration's state, failures and recorded lines) that you can select and copy. |
| `/kt probe` | Opens a window with a report on the game's API (for bug reports). |
| `/kt probe hover` | The same for the item under the mouse. |
| `/kt probe path <name>` | Describes one global table, e.g. `DFLProfessionJournalNS.API`. |

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
