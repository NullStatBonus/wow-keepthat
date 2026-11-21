# Proposal

## Why

The Shift details list the endgame recipes that use a material, but do not say whether this character knows them or whether crafting them still raises skill. Players must open the profession window to decide whether to keep, use or sell the material (issue #16).

## What Changes

- Each endgame recipe line in the Shift details gains a short status in parentheses: `(Learned · Yellow)`, `(Learned · Gray)`, `(Not learned)`. The color word is drawn in the game's difficulty color, and the word is always there as well, so color is never the only signal.
- Difficulty comes from the recipe's skill thresholds in the game data, compared with the character's current rank. It needs no open window.
- Learned status comes from what the character has been seen to know. That is a client API if a probe shows one is reliable, otherwise a record taken each time the profession window opens, saved per character.
- When this character's knowledge for a profession has never been recorded, the block shows one grey hint to open that profession. Unknown is never shown as "Not learned".
- The status refreshes after a recipe is learned or a rank changes.
- The one-line hover summary does not change. The purpose, the counts and the leveling and stock blocks do not change.
- The catalog gains two thresholds per recipe, and both catalogs are regenerated.
- The recipe lines list learned recipes first. A new Home setting, "Recipe order", under "Tooltip line" lets players pick Learned first (default), Not learned first, or Highest skill first.

## Capabilities

### New Capabilities
- `recipe-knowledge`: which recipes the current character is known to have learned. It covers where that knowledge comes from, how it is kept across sessions, and how "unknown" is kept apart from "not learned".

### Modified Capabilities
- `material-tooltip`: the endgame recipe lines in the Shift details show learned status and difficulty, with one hint when knowledge is unknown.
- `material-catalog`: the shipped catalog carries each recipe's difficulty thresholds.
- `settings`: a new "Recipe order" setting on Home, and its default.

## Impact

- **Code:** `tools/build-catalog.py` and both `Data/Catalog_*.lua` files; `Model/Wording.lua` (recipe lines); a new plain-Lua model for difficulty and knowledge; new adapter functions in a new `Core/Adapter_Recipes.lua` for the trade skill and craft windows; `Core/Addon.lua` events; `UI/Tooltip.lua` passes the new context; `Debug/Probe.lua` adds candidates; `Core/Defaults.lua` and `Options/Options.lua` add the setting.
- **Saved variables:** a new per-character record of known recipes. It is additive, and no existing data changes.
- **Docs:** README (Shift details, "Good to know" limits), `docs/listing.md`, `docs/test-plan.md`, `docs/data.md` (catalog format), `docs/contracts.md` (probe results on both clients).
- **Version:** minor bump to 0.5.0 at sync or archive (new player-visible capability).
