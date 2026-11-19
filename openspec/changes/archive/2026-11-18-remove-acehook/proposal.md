# Proposal

## Why

KeepThat loads AceHook-3.0 but never calls it: its hooks use the game's `hooksecurefunc` (`Core/Adapter_Bags.lua`). The unused library adds load time and package size, and is one more embedded copy to keep in step with the other addons (issue #13).

## What Changes

- Drop `"AceHook-3.0"` from the `NewAddon` mixins in `KeepThat/Core/Addon.lua`.
- Delete its `<Include>` line from `KeepThat/embeds.xml` and the `KeepThat/Libs/AceHook-3.0/` folder.
- Remove it from the bundled list in `KeepThat/Libs/VERSIONS.txt`.
- Update `tests/test_core.lua` to expect only AceEvent-3.0 and AceConsole-3.0.
- Release as patch 0.4.1. Nothing changes for players.

Out of scope: the same leftover in Don't Do That (another repository).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No spec-level behavior changes; the change sets `skip_specs: true`.

## Impact

- Files: `KeepThat/Core/Addon.lua`, `KeepThat/embeds.xml`, `KeepThat/Libs/AceHook-3.0/` (deleted), `KeepThat/Libs/VERSIONS.txt`, `tests/test_core.lua`.
- No settings, saved data, commands or docs change. A repo-wide search found no other reference (no `Hook`, `SecureHook`, `RawHook`, `Unhook` or `IsHooked` calls outside `Libs/`).
- Another addon that embeds AceHook-3.0 keeps its own copy through LibStub; KeepThat no longer registers one.
