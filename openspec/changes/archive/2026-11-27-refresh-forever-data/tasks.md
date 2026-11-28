# Tasks

## 1. Catalog

- [x] 1.1 Check `wago.tools/builds` for the newest `wowf` build and set `BUILDS["forever"]` in `tools/build-catalog.py`
- [x] 1.2 Regenerate `Catalog_Forever.lua` (`python3 tools/build-catalog.py --client forever`) and diff it against the old file; list recipes added, removed or moved and any reagent or threshold changes
- [x] 1.3 Fix any endgame-list failure the build reports (an item that is no longer a reagent of its profession)
- [x] 1.4 Update the Forever build in `THIRD_PARTY.md`

## 2. Routes

- [x] 2.1 Re-read the Metabot Forever pages for all eight professions and rewrite `tools/routes/forever/metabot/*.txt` with the current steps and a new `# checked:` date
- [x] 2.2 Re-read the RankedBoost Forever pages for all eight professions and rewrite `tools/routes/forever/rankedboost/*.txt` (Blacksmithing changed; confirm the rest); update `# checked:`
- [x] 2.3 Run `python3 tools/build-routes.py --client forever`; fix any unresolved recipe name or coverage gap
- [x] 2.4 Update the Forever rows of the guide table in `THIRD_PARTY.md` with the new checked date

## 3. Tests

- [x] 3.1 Run `make test`; for each failing Forever assertion in `tests/test_data.lua`, `tests/test_leveling.lua` and `tests/test_classify.lua`, confirm the new value matches the regenerated data and a route or recipe change, then update it
- [x] 3.2 Add or adjust one test that fails when a Forever route file lacks a checked date, if no existing test already checks this
- [x] 3.3 Break the new check on purpose, confirm it fails for the expected reason, then restore it

## 4. Documentation

- [x] 4.1 Update the DFL Profession Journal section of `docs/contracts.md` to 3.16.97: entry points re-checked, no route-data change in its changelog, data file about 0.2% larger, pipeline id unchanged, broker launcher and crest, other guides named in `GuideComparisonData.lua`
- [x] 4.2 In `docs/data.md`, state that Metabot Forever routes are recomputed and must be re-snapshotted when the catalog build moves
- [x] 4.3 Check `README.md`, `docs/listing.md` and `plans/keepthat.yaml` for the old build number or Forever counts; update any that appear

## 5. Verify and archive

- [x] 5.1 Run `make test` and `make check`
- [x] 5.2 Archive the change (`/opsx:archive`): patch version bump in both TOC files, a `CHANGELOG.md` section in the required style (what players saw before, counts now higher on WoW Forever), then commit
