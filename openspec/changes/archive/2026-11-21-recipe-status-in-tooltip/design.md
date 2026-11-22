# Design

## Context

- `Model/Wording.lua` `Details` builds the Shift lines. Endgame blocks list up to three recipes (`recipesUsing`, sorted by `learn`) as `<name> - <qty> per craft`, of kind "note". Leveling blocks list no recipes.
- `Core/Context.lua` gives `skills = { [profession] = rank }` and is invalidated on `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL` and `LEARNED_SPELL_IN_TAB`/`_IN_SKILL_LINE` (`Core/Addon.lua`).
- `tools/build-catalog.py` already downloads `SkillLineAbility`. Its columns include `TrivialSkillLineRankLow` and `TrivialSkillLineRankHigh`. Measured in the cached CSVs (2026-11-21):
  - Linen Bandage (3275): 30 / 60 on both clients. Wowhead shows 1 / 30 / 45 / 60.
  - Transmute: Arcanite (17187): 275 / 290.
  - Mooncloth (18560): 290 / 320 on Era and 270 / 300 on Forever.
  - 59 of 1631 profession rows have zero or inverted values.
- **`MinSkillLineRank` is 1 for many trainer recipes** (Silk Bandage, Mooncloth), so the catalog's `learn` is not the required skill, and the orange start is not in the data.
- Test characters have Skinning, Herbalism, Tailoring and Enchanting. Tailoring covers the trade skill window and Enchanting the craft window on Era. Skinning and Herbalism are gathering professions and are not covered.
- Clients (wow-api, 2026-11-21):
  - Classic Era uses `GetTradeSkillInfo(i)` (name, skillType, …) and `GetTradeSkillRecipeLink(i)` for most professions.
  - Classic Era Enchanting uses the Craft API (`GetCraftInfo`, Blizzard_CraftUI/Vanilla).
  - Forever has `C_TradeSkillUI.GetRecipeInfo(spellID)`, whose `TradeSkillRecipeInfo` has `learned`, `relativeDifficulty` and `maxTrivialLevel`.
  - `IsPlayerSpell` is an undocumented global; whether it reports recipes is unknown on both clients.
- Classic Era Vanilla Craft UI has `GetCraftItemLink` but no `GetCraftRecipeLink`.

## Goals / Non-Goals

**Goals:**
- Difficulty with no open window, from generated data plus the live rank.
- Learned status that never shows "Not learned" on a guess.
- One probe action per client settles every open data question (D1, D3).

**Non-Goals:**
- Status on leveling blocks: they list no recipes today.
- Showing a required skill.
- Reading DFL Profession Journal's known/not-learned flag. It could be a later optional source; the feature stays standalone.
- Other characters' recipes.

## Decisions

### D1. Thresholds: yellow = TrivialLow, gray = TrivialHigh, green = floor((yellow + gray) / 2), probe-gated
- The generator writes `yellow` and `gray` per recipe (`y = 275, gy = 290`). It omits both when either is 0 or `gray < yellow`. Green is computed in Lua, not stored.
- The midpoint matches Linen Bandage (45) and Wowhead's convention for Transmute: Arcanite (282). It is a hypothesis until task 1 compares it with the client's own `skillType`/`relativeDifficulty` for every visible recipe. If the probe disagrees, change the rounding or store a third threshold from another column. That changes only the generator and the model, not the spec.
- Difficulty at rank r: below yellow is Orange, below green is Yellow, below gray is Green, otherwise Gray.
- **Alternative:** read difficulty from the open window only. Rejected, because it would be stale between window openings and empty until the first one.

### D2. Below yellow, difficulty shows only for a learned recipe
Without the required skill, "orange" and "too low to learn" look the same. So a recipe gets a difficulty word below yellow only when it is known to be learned (state `true`): learning it proves the rank meets the requirement. For not-learned and unknown recipes, the word appears only at rank ≥ yellow.

### D3. Knowledge source: window record by default, client API only after a probe proves it
- `Model/RecipeKnowledge.lua` (plain Lua) holds the record and answers `State(profession, spellID) -> true | false | nil`.
- **Window record (both clients):** `Core/Adapter_Recipes.lua` reads the open window.
  - Era trade skills: `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillRecipeLink` → spell ID from the `enchant:` link.
  - Era Enchanting: the Craft equivalents.
  - Forever: `C_TradeSkillUI`. The first read after the window opens says "not learned" for every recipe (probe, 2026-11-21). So a Forever read is incomplete when `IsPlayerSpell` knows a recipe that `GetRecipeInfo` calls unlearned. The next `TRADE_SKILL_LIST_UPDATE` gives the complete read.
  - Recipes are keyed by **spell ID**, never by name, because client names are localized.
  - The adapter also reports whether the read was complete: no search text, no "have materials" or subclass/slot filter, no collapsed header.
- **Complete read** replaces the profession's record and sets `complete = true`. **Incomplete read** only adds learned spells.
- **Client API:** if task 1 shows `IsPlayerSpell` (or Forever's `GetRecipeInfo(...).learned` with the window closed) returns true for known recipes and false for unknown ones, `State` may use it on that client. The probe result is recorded in `docs/contracts.md`, and the code path is chosen by function existence plus that contract. If it is unproven, it is not used.
- **Alternative:** scan only the known spells list. Rejected, because recipes are not in the spellbook on Classic.

### D4. Storage: `db.global.recipes[<character key>]`
- Format: `{ [profession] = { complete = bool, known = { [spellID] = true }, at = time } }`.
- It uses the same character key as the stock recorder (`Core/Stock.lua`), read from the same `Adapter.PlayerIdentity()`, so recipes work even when stock recording is off. It does not use AceDB `char`. AceDB-3.0 minor 40 renamed Forever's character key (`Model/ProfileKey.lua`), and stock already avoids that by keeping its own key.
- No migration is needed: missing means unknown.
- When a profession leaves the character's skills list (Context sees it gone, not hidden under a collapsed header), its record is dropped. Otherwise old recipes would show "Learned" after the profession is learned again.

### D4b. Recordable professions
- A profession is recordable on a client when the adapter has a read path for its window there. The proof is the 1.3 probe and `docs/contracts.md`.
- The hint shows only for recordable professions, so it can always be cleared.
- A read that shows another player's recipes is skipped: a linked or guild profession, or an NPC crafter (`IsTradeSkillLinked`, `C_TradeSkillUI.IsTradeSkillLinked`/`IsTradeSkillGuild`/`IsNPCCrafting`, whichever exist).
- If a craft-window read has rows but no spell IDs, Enchanting is marked not recordable for the session, so its hint clears.
- **Forever only in this version (2026-11-21):** the test characters with Tailoring and Enchanting are on WoW Forever only, so the Classic Era window reads cannot be verified in game. `Adapter.WINDOW_ROWS_VERIFIED = false` turns off the row-reading path, which is the path without `C_TradeSkillUI.GetRecipeInfo`. The choice is made by which API exists, not by the client's name. Era recipes stay unknown and show difficulty only. The code and tests stay, ready for an Era probe.
- Era Enchanting is the risk: Vanilla's Craft UI has `GetCraftInfo` and `GetCraftItemLink`, but no `GetCraftRecipeLink` (wow-api source search, `Blizzard_CraftUI/Vanilla`). If `GetCraftItemLink` does not carry the spell ID for enchants, Enchanting is not recordable on Era and shows difficulty only.

### D5. Learning never produces a false "Not learned"
- **Primary:** `NEW_RECIPE_LEARNED(recipeID)` exists on Classic Era (generated TradeSkillUI docs, 2026-11-21) and on Forever. When its ID is a catalog recipe, add it to that profession's `known`.
- **Also:** `LEARNED_SPELL_IN_TAB`/`_IN_SKILL_LINE` carrying a catalog recipe ID do the same. Any other ID (class spells at level-up) is ignored and changes no record.
- **Fallback, only if the task 1.3 probe shows a recipe learned with the window closed fires no event carrying its ID:** after any `LEARNED_SPELL_*` event whose ID is not in the catalog, set every record `complete = false` (unknown) until each window opens again. No global string for "You have learned how to create" was found in the Classic Era source, so chat parsing is not an option.
- In every case Context is invalidated, as today.

### D6. Wording
- `Details` takes `ctx.recipeStatus(profession, spellID) -> { learned = true|false|nil, difficulty = "orange"|... | nil }` and `ctx.knowledgeKnown(profession) -> bool`. Keeping the model out of Wording keeps Wording testable with fakes.
- Strings: `L["(%s)"]`, `L["Learned · %s"]`, `L["Not learned"]`, `L["Orange"]`, `L["Yellow"]`, `L["Green"]`, `L["Gray"]` and `L["    Open %s to see which recipes you know"]`. These are whole fragments with no concatenation of sentences. The status is joined with the existing `L["%s %s"]`.
- Colors are Blizzard's `TradeSkillTypeColor`: optimal ff8040, medium ffff00, easy 40bf40, trivial 808080. They are tooltip text, not a persistent fill.
- The hint is one line at the end of that profession's endgame block, after any `and N more recipes` line, kind "note".
- A learned recipe with no thresholds shows `(Learned)`.
- **Codex planning review (2026-11-21), applied:**
  - Recipe text, parentheses and knowledge words stay note grey #999999; only the difficulty word is colored.
  - One parenthetical after `per craft`, with ` · ` inside it. A second hyphen would compete with the name-quantity separator, and a comma reads as prose.
  - Hint wording is action-first.
  - Final strings: `Transmute: Arcanite - 1 per craft (Learned · Yellow)`, `Arcanite Reaper - 12 per craft (Not learned)`, `Transmute: Arcanite - 1 per craft (Yellow)`, `Open Alchemy to see which recipes you know`.
  - Still open for 5.1: in-game wrapping of a long localized recipe name at a large tooltip font.
- **Codex implementation review (2026-11-21), applied:**
  - `AddLine` already wraps (fifth argument true), and `|r` returns the line to note grey after the colored word.
  - The preview sample now mixes learned and not-learned recipes, so the order setting visibly changes something.
  - The setting's hover text is now "Choose which recipes appear first when you hold Shift over an endgame material."
  - **Not applied:** renaming the label to "Tooltip recipe order". "Recipe order" sits directly under "Tooltip line", and the spec and README name it that way.
  - Still to see in game: a long localized recipe name at a large font.

### D8. Recipe order: a setting, default learned first
- `profile.recipeOrder` = `"learned"` (default), `"unlearned"` or `"skill"`.
- Learned: learned, unknown, not learned. Unlearned: not learned, unknown, learned. Skill: one group.
- Within a group, sort by `y` descending, then spell ID. Recipes without `y` go last.
- Wording receives the order in `ctx.recipeOrder`, so tests pass it directly.
- This replaces the sort by `learn`, which is 1 for many trainer recipes and so effectively sorted by spell ID.
- A profession the character does not have counts as all unknown, so its lines are ordered by yellow rank.
- On 2026-11-21 the user asked for a customizable order, defaulting to learned first.
- **Placement:** an AceConfig `select` on Home, directly under "Tooltip line". It is disabled while the tooltip line is off, the same pattern as "Show the tint in" under "Icon tint". A new menu entry is a key decision: it was surfaced to the user, and Codex reviews it in 5.1.
- **Alternative:** Appearance. Rejected, because the setting changes what the tooltip lists, not how it looks.

### D7. No on/off toggle for the status
The status lives inside the Shift details, which players already chose to expand. Only the order is configurable (D8). That keeps the menus lean.

## Risks / Trade-offs

- [The midpoint formula is wrong for some recipes] → The task 1 probe logs mismatches per profession. Unit tests pin the formula, and a mismatch count over 0 blocks the release.
- [The completeness check misses a filter, so recipes are wrongly shown "Not learned"] → The probe logs the visible-row count next to the record. Only filters the adapter can read count as known-clear, and when a filter function is missing the read is incomplete.
- [Era Craft API differs from TradeSkill] → It is a separate adapter path with its own fake in tests. The probe covers Enchanting explicitly.
- [Saved-variable growth] → About 300 spell IDs per profession per character, which is negligible.
- [Tooltip lines get longer] → The status adds at most about 20 characters to at most 3 lines. A Codex visual review is required before implementation (memory "Codex visual review").
