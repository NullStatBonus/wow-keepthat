# Tasks

## 1. Skeleton and in-game spikes

- [ ] 1.1 Create the repository skeleton from design D1: both TOCs (11509, 16001, version 0.1.0), `embeds.xml`, the Ace3 r1403 subset copied from `../wow-dontdothat/DontDoThat/Libs` with `VERSIONS.txt` and `LICENSE-Ace3.txt`, `Locales/enUS.lua`, `Core/Init.lua` and `Core/Addon.lua` (AceAddon only). Also copy `tests/run.lua` and the harness, `tools/check-*.sh`, the `Makefile`, MIT `LICENSE` and `.gitignore`. Write `CLAUDE.md` from all of Closest Vendor's (`../wow-closest-vendor/CLAUDE.md`): the sections Delegation, Releases, Git and PRs, Documentation and Conventions, with the module names in Conventions made generic so the file can be copied into the next addon unchanged except for names. Test files are named `tests/test_<module>.lua`, as in Closest Vendor. Verify the five sections exist in `CLAUDE.md` and `make test` finds the `test_*.lua` files. Also verify `make test` and `make check` pass and the addon loads in game with no errors on both clients.
- [ ] 1.2 Add `Core/Adapter.lua` and `Debug/Probe.lua`, adapted from Don't Do That's probe, with groups for tooltips (`TooltipDataProcessor`, `OnTooltipSetItem`), loot (`CHAT_MSG_LOOT` format strings), containers (`C_Container.*`, `ContainerFrame_Update*`), and detection of Baganator, Bagnon, EllesmereUI, Auctionator (`Auctionator.API.v1`) and Profession Journal globals. Add `/kt probe` to print the report. Verify a probe test passes under `make test`, and that `/kt probe` runs on both clients.
- [ ] 1.3 Spike with the user in game: run `/kt probe` on Forever (with EllesmereUI Bags, Auctionator and DFL Profession Journal) and on Classic Era (base APIs only: tooltip, loot, containers, items, skills). Record in `docs/contracts.md`: the tooltip hook available on each client, the loot message format, how EllesmereUI's bag buttons are named and updated and whether it runs on Forever, the shape of Profession Journal's route data, and whether Skillet-Classic and LazyProf run on Forever (for the deferred list). Verify `docs/contracts.md` has an entry for each item, and update design D4, D6 and D7 if a finding changes them.

## 2. Catalog and leveling data

- [x] 2.1 Write `tools/build-catalog.py --client era|forever` (design D2). It reads that client's DB2 recipe tables and writes `Data/Catalog_Era.lua` and `Data/Catalog_Forever.lua` with recipes and quantities. Verify a generator test on a small fixture, and a Lua test that both catalogs load and every entry has a profession, a category and a source (`material-catalog`, "Every entry cites its source", "A catalog for each client").
- [x] 2.2 Curate `tools/endgame/<client>/<profession>.txt` for every crafting profession on both clients: raid and dungeon consumables, each class's best-in-slot crafted gear, and other mats the guides call essential, each with a citation and a reason. Verify by review with the user, and by a test that every listed item ID resolves in that client's catalog.
- [x] 2.3 Record the 1-300 routes of the cited free guides as facts in `tools/routes/<client>/<guide>/<profession>.yaml` (wow-professions.com and Wowhead Classic for Era; Metabot and RankedBoost for Forever, because Icy Veins and Mobalytics refuse automated reads; every recipe is resolved against that client's game data), and generate `Data/Routes_Era.lua` and `Data/Routes_Forever.lua` as material segments for each guide (design D3). Verify a test that each route covers skill 1 to 300 without gaps and that segment totals equal crafts times reagent quantity.
- [x] 2.4 Credit every data source (wago.tools/DB2, each guide with its URL and the date it was checked) in `THIRD_PARTY.md`. Verify each source named in the data appears there.
- [x] 2.5 List each client's data files only in its own TOC, and set `ns.client` and `ns.Data.Catalog` and `ns.Data.Routes` from the loaded files in `Core`. Verify a test that loads each TOC's file list and gets the right client, and that `make check` passes.

## 3. Classification and wording (pure Lua)

- [x] 3.1 Implement `Model/Classify.lua`: endgame, leveling, both or unmarked, from the catalog, the category toggles, the per-material `disabled` set, the client flag, and the steps already passed. Verify tests for every `material-catalog` scenario, and the passed-step scenario from `leveling-guidance`.
- [x] 3.2 Implement `Model/Leveling.lua` (design D3): the union of sources, the largest remaining count from the player's current skill (in proportion inside a segment), the whole route when the profession is unknown, the source names, and no count when data is missing. Verify tests for each `leveling-guidance` scenario except Profession Journal.
- [x] 3.3 Implement `Model/Wording.lua`: the single line (`Endgame: X`, `Leveling: X`, `Endgame + Leveling: X`, two names plus `+N`) and the lines shown with Shift, all through `L[...]`. Verify tests for each wording scenario in `material-tooltip`, and that the locale test passes.

## 4. Settings

- [x] 4.1 Add AceDB with the defaults (design D8) and the pages Home, Materials, Integrations, Advanced and About as pure builders in `Options/Options.lua`, plus `/kt`. Verify options tests for the defaults, for applying changes without a reload, and for the `settings` scenarios on toggles surviving updates and on a second character.
- [ ] 4.2 Build the Materials tree: one node per profession, split into Endgame and Leveling, with a toggle, recipes, counts, source and copyable Wowhead links for every material. Verify an options test for the Arcanite Bar scenario and the category-off scenario, and check it in game.
- [x] 4.3 Add `Debug/Log.lua` and `Debug/Export.lua` with `/kt debug on|off` and `/kt log`. The report lists every setting, each integration's state and recorded failures. Verify a test for the debug report scenario.
- [x] 4.4 Write the Settings and Commands sections of `README.md`, and the settings checks in `docs/test-plan.md`. Verify the commands documented in the README match `Core/Slash.lua`.

## 5. Tooltip line

- [ ] 5.1 Implement `UI/Tooltip.lua` with the hook chosen by capability (design D5), the once-per-tooltip guard, and a refresh when Shift is pressed or released. Verify adapter tests with fake tooltips for both hook paths, and check in game the bag, merchant, auction house, loot, mail, trade, chat link and recipe reagent tooltips on both clients.
- [x] 5.2 Document the tooltip in `README.md` and `docs/test-plan.md`. Verify the test plan has one numbered check for each `material-tooltip` scenario.

## 6. Loot toast

- [ ] 6.1 Implement `UI/Toast.lua` (design D6): match the loot patterns, the session table, combining pickups, a pool of three frames that ignore the mouse, and the fade. Verify tests for each `loot-toast` scenario using fake chat events, and check in game, including gathering several stacks of ore.
- [x] 6.2 Document the toast in `README.md` and `docs/test-plan.md`. Verify the test plan covers each `loot-toast` scenario.

## 7. Icon mask

- [ ] 7.1 Implement `UI/Overlay.lua` (`Apply`, re-coloring on setting changes, the location filter), `Integrations/Blizzard.lua` and `Integrations/Merchant.lua` (merchant and buyback, both clients). Verify tests with fake buttons for the tint, the both-categories color, a moved item and a location turned off, then check the default bags and bank in game on both clients.
- [ ] 7.2 Implement the gate that keeps integrations to WoW Forever (design D1b), then `Integrations/Baganator.lua` and `Integrations/Bagnon.lua`, each with a toggle and failure handling in `pcall`. Verify a test that no integration starts on Classic Era. Verify tests that an integration that throws is disabled and logged, then check each bag addon in game.
- [ ] 7.3 Implement `Integrations/EllesmereUI.lua` with `EUI_Bags.RegisterItemOverlayIcon` (contract in `docs/contracts.md`). Verify a test with a fake `EUI_Bags`, including a placeholder slot and a painter error, then check in game on Forever.
- [x] 7.4 Document the icon mask and the Integrations page in `README.md` and `docs/test-plan.md`. Verify the test plan covers each `icon-mask` scenario.

## 8. Auctionator and Profession Journal

- [ ] 8.1 Implement `Integrations/Auctionator.lua` (design D9): export by profession and category, the quantity still needed, replacing only `KeepThat:` lists, and a disabled control when Auctionator is missing. Verify tests against a fake `Auctionator.API.v1`, then export in game.
- [ ] 8.2 Implement `Integrations/ProfessionJournal.lua` (design D4) as one more leveling source, with the shape check and a quiet fallback. Verify tests for the installed, larger-count, unreadable and missing cases, and that the details name Profession Journal in game.
- [x] 8.3 Document both integrations in `README.md` and `docs/test-plan.md`. Verify the test plan covers each `auctionator-export` and `leveling-guidance` scenario.

## 9. Publishing

- [x] 9.1 Copy `.pkgmeta`, `.github/workflows/ci.yml` and `release.yml` from Don't Do That with the names changed (design D10). Write `docs/publishing.md` and `docs/localization.md`. Verify `make check` passes and the packager runs locally or in CI without uploading.
- [x] 9.2 Write `docs/listing.md` with the fields table, the one-sentence summary and the description agreed in exploration, adjusted to the 1.3 findings. Verify every feature it claims exists in the specs.
- [ ] 9.3 End-to-end check: on both clients with the default settings, only the endgame tooltip line appears; turning on each feature in turn works; removing each optional addon causes no errors. Verify by running `docs/test-plan.md` in full.

## Workflow follow-up

- The user creates the CurseForge and Wago projects, adds their IDs to both TOCs, and sets the `CF_API_TOKEN` and `WAGO_API_TOKEN` secrets.
- Run `/opsx:archive` (sync specs, set the version to 0.1.0, write `CHANGELOG.md`), then commit and tag `v0.1.0`.
