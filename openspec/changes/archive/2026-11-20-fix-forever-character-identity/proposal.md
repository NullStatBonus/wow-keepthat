# Proposal

## Why

The bug review of 0.4.4 (2026-11-20) found two WoW Forever defects caused by surnames. Both affect players right now:

- **Stock is grouped by surname, not realm.** On Forever, `UnitFullName("player")` returns the surname where the realm used to be. KeepThat takes that as the realm, so alts with different surnames never share stock, and `/kt status stock` names the surname as the realm.
  - Characters are also keyed by first name only, so two alts with the same first name would overwrite each other.
- **The 0.4.4 profile rename can hand one character's settings to another.** Two Forever characters with the same first name on one realm share the old name "Name - Realm".
  - If one of them chose that profile under 0.4.3 and the other logs in to 0.4.4 first, the profile moves to the wrong character. The first character falls back to defaults.
  - Reproduced with the shipped AceDB.

This is the first of the small patch releases planned from that review. It needs three in-game checks.

## What Changes

- **Stock identity on Forever.**
  - The stock realm always comes from the realm name.
  - When the client uses surnames (`RegionalUniqueNamesEnabled` true), a character is recorded as "Name Surname", the same name the settings library uses.
  - Classic Era identities are unchanged.
- **Moving existing records.** At login, a Forever character's record saved under the surname "realm" and first name is moved to its realm and full name, once, only when nothing is saved there yet.
  - Each alt's record moves the next time that alt logs in.
- **Profile rename guard.** The earlier-named profile is not moved when another character's profile choice still names it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `character-stock`: adds how a character is named and which realm it belongs to on WoW Forever, and how records saved under the old naming are moved.
- `settings`: "Character profile follows the new character name" skips the move while another character still uses the earlier-named profile.

## Impact

- **Code:**
  - `Core/Adapter_Stock.lua` (`PlayerIdentity`)
  - `Model/Stock.lua` (a plain-Lua function that moves a record)
  - `Core/Stock.lua` (calls it at login)
  - `Model/ProfileKey.lua` (`Rename`)
- **Tests:**
  - `tests/test_adapter_stock.lua`
  - `tests/test_stock.lua` (model)
  - `tests/test_stock_recorder.lua`
  - `tests/test_profilekey.lua`
- **Docs:**
  - `docs/contracts.md` (Forever `UnitFullName` return, stock identity)
  - `docs/test-plan.md` (new section with 3 checks)
  - `README.md` "Good to know" (each alt's stock comes back after its next login)
- **Saved data:** no format or version change. Records are only moved within `global.stock.realms`.
- **Release:** patch, 0.4.5.
