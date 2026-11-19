# Proposal

## Why

Issue #20. 0.4.3 restores a WoW Forever character's own profile under its old name ("Name - Realm"), but AceDB 40 names the character "Name Surname". Turning Advanced > "This character" off and on then selects a new, empty profile under the new name, and the old settings become unreachable: KeepThat has no profile picker.

## What Changes

- At load, on clients where AceDB's character name differs from the old one, a profile saved under the old name moves to the new name once, when no profile exists under the new name yet:
  - character using the old profile: it switches to the new name with the same values, and the old one is removed;
  - character on the shared settings: the saved profile is moved to the new name without switching, so turning "This character" on later brings it back.
- A profile that already exists under the new name is never overwritten; both are left as they are (players who already toggled off and on after 0.4.3 keep both).
- Classic Era is unchanged (the names are the same).
- README drops the "starts a new, empty profile" limit; the test plan checks the fix.
- Patch release 0.4.4.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `settings`: adds "Character profile follows the new character name".

## Impact

- `KeepThat/Model/ProfileKey.lua` (a rename step after the existing migration), `KeepThat/Core/Addon.lua` (call order unchanged: both before the presentation upgrade).
- Tests: `tests/test_profilekey.lua` (real AceDB 40 on Forever- and Era-shaped stubs).
- Docs: README Advanced bullet, `docs/test-plan.md` §10, `docs/contracts.md` migration note.
- Saved data: `KeepThatDB.profiles` (one entry renamed) and `profileKeys` for that character. Nothing else.
