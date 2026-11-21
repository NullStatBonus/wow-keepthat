# Tasks

## 1. Probe (gates D1, D3, D4b, D5)

- [x] 1.1 Add the probe candidates to `Probe.Candidates` and verify them with `tests/test_probe.lua`:
  - `IsPlayerSpell`, `IsSpellKnown`
  - `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillRecipeLink` and the trade skill filter getters
  - `GetNumCrafts`, `GetCraftInfo`, `GetCraftItemLink`
- [x] 1.2 Add a debug-only recipe probe for when a profession window opens. For each visible recipe it logs:
  - spell ID, or the link it got
  - the client's difficulty and D1's computed difficulty
  - `IsPlayerSpell`, and on Forever `C_TradeSkillUI.GetRecipeInfo().learned`
  - the completeness signals

  It writes one summary line per profession: rows, formula mismatches, API agreement. It also logs every learn event (`NEW_RECIPE_LEARNED`, `LEARNED_SPELL_IN_*`) with its arguments. Verify with a unit test on a fake window in `tests/test_recipeknowledge.lua`.
- [ ] 1.3 In-game on WoW Forever (the only client with test characters; Classic Era recording stays off, D4b), with Tailoring and Enchanting:
  - turn on debug logging and `/reload`
  - open Tailoring and Enchanting once each
  - learn one Tailoring or Enchanting recipe with the window closed

  Record the results in `docs/contracts.md`:
  - formula mismatches
  - completeness signals
  - API reliability
  - which learn events fire with which ID
  - today's wow-api findings (Era Craft API shape, Forever `TradeSkillRecipeInfo` fields)

  If a result contradicts D1, D4b or D5, update `design.md` (and the spec, if behavior changes). The "learn a recipe with the window closed" step decides D5: if no learn event carries the recipe ID, wire the `K.Unsure` fallback before archive.

## 2. Catalog thresholds

- [x] 2.1 Make `tools/build-catalog.py` write `y` and `gy` per recipe from `TrivialSkillLineRankLow`/`High`, omitting both when they are zero or inverted. Verify with `tools/test_build_catalog.py` (normal, zero and inverted cases) and `make test-py`.
- [x] 2.2 Regenerate both catalogs with `make catalog`. Spot-check Transmute: Arcanite (275/290), and Mooncloth (290/320 on Era, 270/300 on Forever).
- [x] 2.3 Add a check to `tests/test_data.lua`: every recipe with thresholds has `0 < y <= gy`. Update the catalog format in `docs/data.md`. Verify with `make test`.

## 3. Difficulty and knowledge model

- [x] 3.1 Create `Model/RecipeKnowledge.lua` (new, in both TOCs) with `Difficulty(recipe, rank, learned)` per D1/D2 and `State(record, spellID)` → true/false/nil per D3. It also does merge (complete and incomplete reads), the learn rules (D5), dropping a profession (D4), and recordable professions (D4b). Cover these cases in `tests/test_recipeknowledge.lua`:
  - learned, not learned and unknown
  - incomplete read
  - learn event with a catalog ID and with a non-catalog ID
  - dropped profession
  - no thresholds
  - not learned below yellow, unknown below yellow, and learned below yellow (Orange)
  - each color boundary

  Break each rule once to see its test fail.

## 4. Adapter, storage and events

- [x] 4.1 Create `Core/Adapter_Recipes.lua` (new, in both TOCs). It reads the open trade skill window (Era), the craft window (Era Enchanting, only if 1.3 proved spell IDs) and `C_TradeSkillUI` (Forever), and returns `{ profession, complete, known = { [spellID] = true } }` or nil. Every read is guarded and in `pcall`. It exposes `RecipeKnown(spellID)` only on a client where 1.3 proved the API. Verify with fakes in `tests/test_recipeknowledge.lua`.
- [x] 4.2 Store records in `db.global.recipes[realm][name]`, using the stock recorder's identity (D4). `Core/Recipes.lua` creates them on the first read, and `Core/Defaults.lua` documents them. Verify with `tests/test_core.lua` (no records on a new install) and `tests/test_recipeknowledge.lua` (per character).
- [x] 4.3 In `Core/Recipes.lua`, on its own AceEvent module (as `Core/Stock.lua` does, because `Core/Addon.lua` already handles the learn events on the addon), through `ns.Listen`:
  - On `TRADE_SKILL_SHOW`/`_UPDATE` and `CRAFT_SHOW`/`_UPDATE`, record the read and invalidate Context.
  - On learn events, apply D5.
  - When Context's full skills read no longer has a profession, drop its record. `Core/Context.lua` calls `Recipes.Drop`, and nothing is dropped while a Skills header stays collapsed.
  - Log one line per record change: `recipes: <profession> complete=<bool> known=<n>`.

  Verify with fake events in `tests/test_recipeknowledge.lua` and `tests/test_context.lua`.
- [ ] 4.4 Add a debug report section that shows the source, complete flag and known count for each profession. Verify with `tests/test_log.lua`, then read the `/kt log` output from the in-game run of 1.3.

## 5. Tooltip wording and docs

- [x] 5.1 The Codex planning review is already folded into D6 and the spec. Get a Codex review of the implemented tooltip, including wrapping of a long recipe name at a large tooltip font, and of the "Recipe order" control on Home. If the strings change, update the material-tooltip spec delta in the same step.
- [x] 5.2 In `Model/Wording.lua` `Details`, give endgame recipe lines their status, sort them per D8, and add the hint to the block (D6), with the new `L[...]` keys in `Locales/enUS.lua`. Verify with `tests/test_wording.lua` (every scenario of the ADDED tooltip requirements, including the learned-first order) and `tests/test_locale.lua`.
- [x] 5.3 Make `UI/Tooltip.lua` pass `recipeStatus` and `knowledgeKnown` from Context and the record. The sample preview (`Tooltip.Sample`) shows a learned-yellow line. Verify with `tests/test_tooltip.lua` and `tests/test_tooltip_preview.lua`.
- [ ] 5.4 Update the docs:
  - **README:** Shift recipe status, plus "Good to know" lines: open each profession once per character; filters make the record partial; no required skill is shown; Era Enchanting if 1.3 found it can't be recorded.
  - **`docs/listing.md`:** the same feature text.
  - **`docs/test-plan.md`:** a new section 10, "Recipe status", with one check:
    - Setup: a character with Tailoring; debug logging on, then `/reload`.
    - Action: open the Tailoring window.
    - Check: hold Shift over Runecloth; each Tailoring recipe line says Learned or Not learned, and learned recipes are listed first.
    - Log: `recipes: <profession> complete=true known=<n>`.

  Verify with `tests/test_readme.lua`.

- [x] 5.5 Add a `recipeOrder = "learned"` default in `Core/Defaults.lua`, and a "Recipe order" `select` on Home under "Tooltip line" (disabled while the tooltip line is off, D8), with new `L[...]` keys. Verify:
  - `tests/test_options.lua`: placement, values, disabled state, and the change applying without reload
  - `tests/test_core.lua`: the default
  - `tests/test_export.lua`: the value appears in the `/kt log` report
  - Document the setting in the README settings list, and run `tests/test_readme.lua`.

## 6. Integration

- [x] 6.1 Confirm that `make test` and `make check` pass.

## In-game verification (after merge request, before release)

- Tasks 1.3, 4.4 and 5.4 wait for the WoW Forever probe. They are listed as checkboxes in the PR. Archived with these 3 open by the user's request (2026-11-21).

## Workflow follow-up

- Sync specs. Bump both TOCs to 0.5.0. Write the `## 0.5.0` changelog entry. Archive with `/opsx:archive`. Then commit and open a PR whose body lists the in-game check as a checkbox.
