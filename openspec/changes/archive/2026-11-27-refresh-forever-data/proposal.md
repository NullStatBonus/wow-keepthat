# Proposal

## Why

The WoW Forever data is stale. The catalog is pinned to client build 70938 while wago.tools now has 71139. Both Forever route guides changed after our 2026-11-15 snapshots: Metabot re-planned every profession (its crafts grew 2% to 24%), and RankedBoost changed the first Blacksmithing steps. Leveling counts the player sees for Forever therefore run low. DFL Profession Journal also moved from 3.16.76 to 3.16.97, so `docs/contracts.md` is out of date.

## What Changes

- Re-pin the Forever catalog to the current build and regenerate it. Review what changed in recipes, reagents and difficulty thresholds.
- Re-snapshot the Forever routes for all eight professions from Metabot and RankedBoost, with a new checked date.
- Rebuild the generated route data and credit the new build and dates in `THIRD_PARTY.md`.
- Update the DFL Profession Journal section of `docs/contracts.md` to 3.16.97. Record which entry points were re-checked and that no route-data change was found.
- Record the Forever data sources and the build date in the changelog. The Forever endgame lists stay the Era drafts: Forever raids and loot are hidden until launch (raids open 2026-12-09).
- No change to Era data, settings, commands, or tooltip behavior. Players see different leveling counts on Forever only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Data, docs and generated files change; no requirement does (`skip_specs: true`).

## Impact

- `tools/build-catalog.py` (`BUILDS` pin), `tools/routes/forever/{metabot,rankedboost}/*.txt`.
- Generated: `KeepThat/Data/Catalog_Forever.lua`, `KeepThat/Data/Routes_Forever.lua`.
- Docs: `THIRD_PARTY.md`, `docs/contracts.md`, `docs/data.md` (if the checked-date rule is stated there), `CHANGELOG.md`, version in both TOC files at archive.
- Tests: shipped-data assertions in `tests/test_data.lua`, `tests/test_leveling.lua`, `tests/test_classify.lua` that hard-code Forever counts may need new numbers.
- Out of scope: Forever endgame lists (wait for launch), Era routes, Metabot weighting policy, DFLPJ integration changes.
