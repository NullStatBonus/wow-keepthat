# Proposal

## Why

0.4.5 stopped recording stock on WoW Forever entirely. The player's saved variables (2026-11-20) show three sessions ending with `[stock] FAILED: no player identity; stock is not recorded this session`, and no record newer than 0.4.4.

- 0.4.5 takes the realm from `GetNormalizedRealmName()`, then `GetRealmName()`. On Forever both are empty at login.
- Forever has no realm names. Characters share a world per ruleset, so AceDB-3.0 (minor 40) and Syndicator use the ruleset as the realm. The same save shows Syndicator storing the characters under realm `"PvE"`.

This ships in the same release as the stock-count fixes (0.4.6, PR #24), as the player chose.

## What Changes

- On a client with surnames (`RegionalUniqueNamesEnabled`), the stock realm is the ruleset: "PvE", "PvP", "RP", "RP-PvP" or "Hardcore". This is the same rule AceDB-3.0 uses.
  - A realm name is used only when the client gives no ruleset.
  - Classic Era is unchanged.
- The one-time move from 0.4.5 now goes from the surname "realm" to the ruleset and the full name.
- `/kt status stock` names the ruleset, for example `Stock: 3 characters on PvE (Alliance).`

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `character-stock`: "Character names and realms on WoW Forever". The realm is the ruleset where the client has no realm names.

## Impact

- **Code:** `Core/Adapter_Stock.lua` (`PlayerIdentity`).
- **Tests:**
  - `tests/test_adapter_stock.lua`
  - `tests/test_stock_recorder.lua`
  - new `tests/fixtures/forever_save_044.lua`: the player's real 0.4.4 Forever stock, with names replaced.
- **Docs:**
  - `docs/contracts.md` (Forever realm, measured from the save)
  - `README.md`
  - `docs/test-plan.md`: sections 11 and 12 expect `on PvE`.
- **Release:** same 0.4.6. It is not published yet, so no second bump.
