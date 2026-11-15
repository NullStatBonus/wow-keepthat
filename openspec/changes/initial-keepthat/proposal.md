# Proposal

## Why

Players on Classic Era and WoW Forever vendor, delete or undersell materials they will need later, either for endgame crafting (raid and dungeon consumables, best-in-slot gear) or for leveling a profession. KeepThat tells them which items to keep, with as little on-screen noise as possible, so they can make better decisions. It is the third addon by the same author, after Don't Do That and Closest Vendor, and its skeleton should be reusable for future addons.

## What Changes

- New addon **KeepThat** for Classic Era (`_Vanilla.toc`, Interface 11509) and WoW Forever (`_Camelot.toc`, Interface 16001), MIT licensed, published to CurseForge and Wago.
- **Two material categories**, each turned on or off separately:
  - **Endgame materials**, on by default. These are materials for raid and dungeon consumables, best-in-slot crafted gear for each class, and anything else that expert profession guides call essential at level 60 (skill 300).
  - **Leveling materials**, off by default. These are materials that the common leveling guides for that client use to take a profession from 1 to 300. A material counts when any of the cited guides uses it. The count shown is what the guides need from the player's current skill. When they agree it is one number; when they differ it is a range to keep on hand, from the smallest to the largest. KeepThat never asks the player to choose a route.
- **Works on its own.** Every feature uses built-in data, with no other addon required. Optional addons only add to it, and KeepThat always shows its own rows.
- **Guide sources** are free guides only:
  - Classic Era: wow-professions.com and Wowhead's Classic guides.
  - WoW Forever: Metabot and RankedBoost, with every recipe resolved against Forever's game data. Icy Veins and Mobalytics refuse automated reads.
  - DFL Profession Journal's route is read in game when it is installed, and adds its materials and counts.
  - Paid guides (Zygor, RestedXP) are excluded.
- **Classic Era gets the base functionality first.** That is the catalog, endgame and leveling marks, the tooltip line, the loot toast, the icon mask on Blizzard's bags, and the settings. The integrations with other addons (bag addons, Auctionator, DFL Profession Journal) are built and verified on WoW Forever. On Classic Era they stay off until a later change verifies them there.
- **A catalog for each client.** Classic Era and WoW Forever each get a material catalog built from that client's own game data, because Forever has moved some recipes between professions.
- **Three ways to show a mark**, each turned on or off separately:
  - **Tooltip line**, on by default, the main feature. One short line in style B: `Endgame: <Profession>` (purple) or `Leveling: <Profession>` (green). Holding Shift adds details: the recipes that use the item, and for leveling, the skill range and the count needed.
  - **Loot toast**, off by default. A short toast when you loot a flagged item, using the same wording as the tooltip line. One toast per item per session; later pickups add to the count shown.
  - **Icon mask**, off by default. A colored overlay on item icons; the user picks the color, by default purple for endgame and green for leveling. Version 1 supports Blizzard's default bags and bank, Baganator, Bagnon and EllesmereUI Bags. Each bag addon integration is optional and turns itself off if it fails.
- **Materials review.** One Materials settings page, a tree of profession then material that follows the Home checkboxes and a toggle for every material, all on by default. Each material shows which recipes it is used for and the details that matter, such as counts for leveling and copyable Wowhead links.
- **Auctionator shopping list export.** Export the materials you still need as an Auctionator shopping list.
- **Settings use Ace3 (AceConfig)**, with pages Home, Materials, Integrations, Advanced and About. On Home, a "Show marks in" setting chooses where the icon tint appears (bags, bank, merchant), all on by default.
- **A reusable skeleton**, combining Don't Do That's layout with Closest Vendor's adapter rule: two TOCs, embedded Ace3, a game-call adapter, pure-Lua logic tested with `luajit tests/run.lua`, `L["..."]` strings, `tools/check-*.sh`, `.pkgmeta`, and CI and release workflows using BigWigsMods/packager.

### Deferred (out of scope for this change, to consider later)

- Mark only the materials for the character's own professions (for alts and auction house use).
- TradeSkillMaster integration.
- Skillet-Classic integration: mark flagged reagents in its recipe view.
- LazyProf integration. It shares the problem of leveling counts that may disagree with ours.
- Profession Leveling Guide (PLG) integration for Classic Era. Its current source is not public, so its route data can't be checked yet. Revisit with a local copy of the addon.
- DFL Dungeon Journal: drop sources ("Righteous Orb: Stratholme"), or an API from its author.
- More bag addons: AdiBags, ArkInventory.
- A loot counter for flagged materials, like those in fishing addons.
- Icon tint in the auction house, mail, loot and trade windows. The tooltip line already shows there.
- WoW Forever's own endgame lists (its new raids and zones). Version 1 uses the Classic Era lists on Forever; revisit once Forever's content and guides exist.
- Moving Closest Vendor's settings to AceConfig, to make all three addons consistent.
- Crowdsourced translations. Version 1 ships English only. A likely route is CurseForge's localization tool, which BigWigsMods/packager can fill in at package time.

### Dropped

- A "Uses KeepThat materials" filter in the profession window.
- Hiding KeepThat's leveling line when DFL Profession Journal shows its own "Your route" line. KeepThat always shows its own rows.
- A setting to choose a leveling route. The goal is to show which materials to keep, not to pick a route.
- Zygor and RestedXP as sources, because they are paid.
- WoW Forever's Comprehension profession. KeepThat does not cover it.

## Capabilities

### New Capabilities

- `material-catalog`: the curated data for endgame and leveling materials per profession and per client (recipes, skill ranges, counts, sources), and how an item is classified for the current settings.
- `leveling-guidance`: which materials count for leveling and how many to keep: the union of the cited free guides for each client, the largest count from the current skill, and DFL Profession Journal adding to it when installed.
- `material-tooltip`: the tooltip line, its wording and colors, and the details shown with Shift.
- `loot-toast`: the toast when a flagged item is looted, including coalescing pickups of the same item and the limit of one toast per item per session.
- `icon-mask`: the colored overlay on item icons, and its integrations with the default bags, Baganator, Bagnon and EllesmereUI Bags.
- `auctionator-export`: exporting needed materials as an Auctionator shopping list.
- `settings`: the AceConfig pages, the defaults, the "Show marks in" locations, and the per-material toggles in the Materials review.

### Modified Capabilities

None. This is a new project with no existing specs.

## Impact

- New repository content: `KeepThat/` addon folder (TOCs, `embeds.xml`, `Libs/` Ace3, `Locales/`, `Core/`, `Options/`, `Data/`, `Integrations/`), `tests/`, `tools/` (data generators, check scripts), `.pkgmeta`, `.github/workflows/{ci,release}.yml`, `Makefile`, `LICENSE` (MIT), `THIRD_PARTY.md`, `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `docs/{listing,publishing,localization,test-plan}.md`.
- Dependencies: Ace3 is embedded in the addon. Optional runtime dependencies: Baganator, Bagnon, EllesmereUI, Auctionator, DFL Profession Journal.
- Data research is a major work item, done for each client: recipes for every profession from that client's game data, curated endgame lists, and the materials and counts from each cited free guide's 1-300 route (facts only, with credit). Each data source needs its attribution recorded in `THIRD_PARTY.md`. DFL Profession Journal is All Rights Reserved, so it may only be read at runtime when it is installed, never copied into our data.
- Spikes needed before design is final: how EllesmereUI Bags builds and updates its item buttons, whether EllesmereUI Bags runs on Forever, whether DFL Profession Journal's route data can be read at runtime, how loot is detected on Forever, and whether Skillet-Classic and LazyProf run on Forever.
- Publishing: new CurseForge and Wago projects; their IDs go in both TOCs, and the `CF_API_TOKEN` and `WAGO_API_TOKEN` repository secrets must be set.
