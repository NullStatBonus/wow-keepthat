# Tasks

## 1. Professions start collapsed

- [x] 1.1 Keep `Options.CollapseMaterials(dialog)` in `KeepThat/Options/Options.lua` and call it before `dialog:Open` in both `Options.Open` and `Options.OpenMaterial`; verify with `make test` (the existing collapse checks in `tests/test_options.lua` pass, and a new check shows `OpenMaterial` collapses before selecting its path).
- [x] 1.2 Remove the Settings-window `OnHide` collapse hook added on the branch (that panel no longer has a tree after group 2); verify `make test` still passes and the hook is gone from `Options.lua`.

## 2. Materials launcher in the game's Settings window

- [x] 2.1 Add `ns.Adapter.CloseGameSettings()` to `KeepThat/Core/Adapter.lua`: hides `SettingsPanel` with `HideUIPanel` when it exists, else `InterfaceOptionsFrame`, all in `pcall`, returning nil when neither exists; verify with a new check in `tests/test_adapter.lua` using fake globals (each frame present, and neither present, without error).
- [x] 2.2 In `Options.lua`, build and register the launcher options table (one description and an "Open KeepThat" execute button whose func calls `ns.Adapter.CloseGameSettings()` then `Options.Open("materials")`), and register it with `AddToBlizOptions` in the Materials slot instead of the `materials` path of the main table; write the new sentences as whole `L[...]` strings (enUS needs no entry: the English text is the key). Verify in `tests/test_options.lua`: still six Settings entries in the same order, the Materials entry comes from the launcher app, the button closes Settings and selects `materials`; `tests/test_locale.lua` passes.
- [x] 2.3 Update `README.md` (settings section: Materials in the game's Settings window opens the KeepThat window; professions start collapsed) and add `docs/test-plan.md` section 8 with the manual checks below; verify `make test` (README command check) and `make check` pass.

## 3. In-game verification

- [x] 3.1 On WoW Forever and Classic Era: Esc > Options > AddOns > KeepThat > Materials shows the launcher; Open KeepThat closes Settings and opens `/kt` on Materials; moving from Materials to every other KeepThat entry has no noticeable pause; expanded professions are collapsed after closing and reopening `/kt`; `/kt find` opens only its profession. Record results in `docs/test-plan.md` section 8.

## 4. Fixes found while testing

- [x] 4.1 Register only events the client has: `ns.Adapter.EventKnown` (via `C_EventUtils.IsEventValid`) and `ns.Listen` in `Core/Addon.lua`; watch `LEARNED_SPELL_IN_SKILL_LINE` where `LEARNED_SPELL_IN_TAB` was removed (Forever raised "Attempt to register unknown event"). Verified by `tests/test_adapter.lua` and `tests/test_smoke.lua` (a removed event is not registered, its replacement is); breaking the guard fails the smoke test.
- [x] 4.2 Baganator icon tint: Baganator 860 freezes its item button mixins (`table.freeze`, `ItemButton.lua:1482-1489`), so hooking them fails ("attempted to perform indexed assignment on a frozen table", seen in game). `Integrations/Baganator.lua` now hooks each button's own `SetItemDetails`, found through Baganator's public skin API (`Skins.GetAllFrames` and `Skins.RegisterListener`), and paints it at once; detection needs a mixin, the gate retries on `ADDON_LOADED`/`PLAYER_LOGIN`, and `docs/contracts.md` records 860. Verified by `tests/test_integrations.lua` (frozen mixins still tint, for buttons built before and after KeepThat starts; guild and bag-slot buttons are skipped; breaking any of these fails it). Mark done once the tint shows in Baganator in game.

## Workflow follow-up

- Archive with `/opsx:archive`: sync the `settings` delta, bump both TOCs to 0.2.1, add a `## 0.2.1` CHANGELOG line.
- Commit, open a PR, and after merge tag `v0.2.1`.
