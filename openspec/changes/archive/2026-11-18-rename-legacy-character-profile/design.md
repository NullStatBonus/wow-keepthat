# Design

## Context

- `Model/ProfileKey.lua` `Migrate(db, oldKey)` (0.4.3) re-selects the profile chosen under the old key, then clears `profileKeys[oldKey]`. It never renames: the restored profile is `sv.profiles["Name - Realm"]`.
- `Options.SetCharacterProfile(on)` calls `db:SetProfile(on and db.keys.char or "Default")`; `CharacterProfileOn` is "current is not Default". Neither changes.
- AceDB 40: `SetProfile(name)` creates the profile on first use; `CopyProfile(name)` resets the current profile and copies `name` into it (source must differ from current); `DeleteProfile(name)` refuses the active profile. `db.profiles` is `sv.profiles`.
- `OnInitialize` runs `ProfileKey.Migrate` before `Presentation.Migrate(self.db.profile)`; the rename must also run before it, because `SetProfile` replaces `db.profile`.

## Goals / Non-Goals

**Goals:** one profile name per character after load, as on Era; no data overwritten.

**Non-Goals:** recovering settings for players who already have both profiles (decided: leave both); a profile picker; renaming profiles of other characters (KeepThat only ever names a profile after the character using it).

## Decisions

### D1. `ProfileKey.Rename(db, oldKey)`, called right after `Migrate`
Plain Lua: return when `db`, `db.sv`, `db.keys.char` or `oldKey` is missing, when `sv.profiles[oldKey]` is missing, or when `sv.profiles[new]` exists (never overwrite). Equal names (Era, older AceDB) need no separate guard: the profile then exists under the new name, so the last check returns.
- **Current profile is `oldKey`:** `SetProfile(new)`, `CopyProfile(oldKey)`, `DeleteProfile(oldKey)`, each step in `pcall`. If `CopyProfile` fails, switch back to `oldKey` and delete the half-made `new` profile so the player keeps working settings; record the failure with `ns.Log.Failure("profile", err)`.
- **Current profile is anything else (Default):** move the table without switching: `sv.profiles[new] = sv.profiles[oldKey]; sv.profiles[oldKey] = nil`. Inactive profiles are plain saved tables (defaults already removed by AceDB), so a raw move is exact and needs no switch. Using the AceDB calls here would switch the active profile twice and fire profile callbacks for nothing.
*Alternative:* fix only `SetCharacterProfile(true)` to prefer an old-named profile. Rejected: keeps two names forever and a special case in the toggle (exploration, option A).

### D2. Wiring
`OnInitialize`: `local old = ns.Adapter.LegacyCharacterKey(); ns.ProfileKey.Migrate(self.db, old); ns.ProfileKey.Rename(self.db, old)`, then `Presentation.Migrate`. One adapter read for both.

## Risks / Trade-offs

- [Players who already toggled off and on after 0.4.3 keep an unreachable old profile] → Accepted (decided); they lose nothing, and it is still in saved data.
- [Rolling back to 0.4.3 or 0.4.2] → AceDB 33 (0.4.2) looks for "Name - Realm" and finds nothing: shared settings until "This character" is turned on, which creates an empty old-named profile. 0.4.3 behaves the same as before the rename. Accepted for a downgrade.
- [An AceDB error midway] → each step in `pcall`, rollback on a failed copy, no Lua error.

## Migration Plan

Runs automatically at the first load of 0.4.4; no player action. Idempotent: after the move, `sv.profiles[oldKey]` is gone, so later loads do nothing.
