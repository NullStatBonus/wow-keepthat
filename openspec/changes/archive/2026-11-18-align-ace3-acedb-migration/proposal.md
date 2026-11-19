# Proposal

## Why

KeepThat, Don't Do That and Closest Vendor embed different Ace3 builds, and LibStub loads the newest of each library from any installed addon (GitHub issue #32 in NullStatBonus/wow-closestvendor). KeepThat ships Release-r1403, whose AceGUI ColorPicker 28 inverts alpha on WoW Forever. Upstream commit `ac3d122` fixes that. It also ships AceDB-3.0 minor 40, which on WoW Forever builds the character key as `Name Surname` instead of `Name - Realm` and does not migrate. Any installed addon that ships AceDB 40 can already cause this today: a Forever character that chose its own KeepThat profile silently falls back to the shared settings.

## What Changes

- Move every embedded Ace3 file in `KeepThat/Libs` to upstream WoWUIDev/Ace3 commit `ac3d122`. The module set stays the same (LibStub, CallbackHandler-1.0, AceAddon, AceEvent, AceDB, AceConsole, AceGUI with widgets, AceConfig with Registry/Cmd/Dialog). AceHook is already gone (0.4.1), and only versions change. Notable bumps: AceDB 33 -> 40, AceConfigDialog -> 93, ColorPicker 28 -> 29, Heading 21, Icon 22, Label 29.
- On load, if the loaded AceDB uses a different character key than AceDB 33 did, the per-character profile choice saved under the old key moves to the new key once. This works whichever AceDB version is loaded.
- Rewrite `KeepThat/Libs/VERSIONS.txt` in a provenance format shared with the sibling addons: the upstream URL and commit, each module's MAJOR and MINOR, the license file, local patches (none) and the update steps.
- Release as a patch, 0.4.2 -> 0.4.3, with the version bump and changelog at archive.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `settings`: "Settings saved per account with profiles" gains the guarantee that a character's profile choice survives the change of AceDB's character key on WoW Forever.

## Impact

- `KeepThat/Libs/**` (library files and XML, `VERSIONS.txt`). `embeds.xml` and the TOC files do not change.
- `KeepThat/Core/Addon.lua` (migration call right after `AceDB:New`). `KeepThat/Core/Adapter.lua` (one guarded read for the old key). A plain-Lua migration function.
- Tests: `tests/test_core.lua` and `tests/stubs.lua` (AceDB 40 needs more client globals), plus new migration tests.
- Docs: `docs/test-plan.md`, `docs/contracts.md`, `THIRD_PARTY.md` (wording check).
- Saved data: only `KeepThatDB.profileKeys`. Profiles, global settings and stock do not change.
