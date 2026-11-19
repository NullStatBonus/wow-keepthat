# Tasks

## 1. Remove AceHook-3.0

- [x] 1.1 Remove `"AceHook-3.0"` from the `NewAddon` call in `KeepThat/Core/Addon.lua` and update `tests/test_core.lua:26` to expect `"AceEvent-3.0,AceConsole-3.0"`; verify `luajit tests/run.lua core` passes, and that it fails if the mixin is put back.
- [x] 1.2 Delete the AceHook `<Include>` line from `KeepThat/embeds.xml` and the `KeepThat/Libs/AceHook-3.0/` folder; verify `make check` passes (`tools/check-embeds.sh`).
- [x] 1.3 Remove AceHook-3.0 from the Bundled list in `KeepThat/Libs/VERSIONS.txt`; verify `rg -i acehook KeepThat tests --glob '!KeepThat/Libs/AceAddon-3.0/**'` finds nothing.

## 2. Verify

- [x] 2.1 Run `make test` and `make check`; both pass.
- [x] 2.2 In game on Classic Era and WoW Forever: log in with no Lua errors, then check that `/kt` opens settings, a material tooltip shows its line, `/kt demo` shows toasts (and plays the sound), and bag tint still works.

## Workflow follow-up

- `/opsx:archive` (no specs to sync): bump both TOCs to 0.4.1, add a `## 0.4.1` CHANGELOG line, commit, PR, tag `v0.4.1` and close #13.
