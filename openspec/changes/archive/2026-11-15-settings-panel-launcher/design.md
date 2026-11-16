## Context

See proposal.md - Why. KeepThat registers one AceConfig table (`KeepThat`) and adds six Settings-window entries with `AceConfigDialog:AddToBlizOptions(APP, name, parent, path)`. Each entry is its own `BlizOptionsGroup` panel, built on show and released on the next frame after hide. The Materials entry currently renders the full profession > material tree there. In-game measurements (debug file, 2026-11-15): KeepThat redraw 160–177 ms, panel release 0 ms, 22 tree buttons, freeze ~77 s on leaving Materials with only KeepThat enabled; none in the `/kt` window.

AceConfigDialog keeps tree open state in `AceConfigDialog.Status[app]` for the session: the root tree's `status.groups` keys are `"materials\001<profession>"`, and the Materials Settings panel has its own `Status[app].children.materials.status.groups` keyed by profession.

## Goals / Non-Goals

**Goals:**
- No Materials tree inside the game's Settings window; one click reaches it in the `/kt` window.
- Professions start collapsed on every open.

**Non-Goals:**
- Finding the exact Blizzard-side cause of the freeze.
- Changing the other five Settings-window panels or the `/kt` window layout.

## Decisions

- **Separate launcher table.** Register a second AceConfig app (`"KeepThat Materials"` internal name) holding one description and one execute button, and add it with `AddToBlizOptions(launcherApp, L["Materials"], APP)` in the Materials slot. Alternative rejected: a hidden group in the main table, because `hidden`/`guiHidden` also hides it in the Settings panel that must show it, and an extra node would leak into the `/kt` tree. A plain description + execute row is the standard AceConfig control, matching addons whose Settings entry only opens their own window.
- **Close the game's Settings window through the adapter.** New `ns.Adapter.CloseGameSettings()` in `Core/Adapter.lua`: if `SettingsPanel` exists, `HideUIPanel(SettingsPanel)` in `pcall`; else if `InterfaceOptionsFrame` exists, hide that. Chosen by checking which frame exists, not by client name. The button then calls `Options.Open("materials")`. If closing fails, the `/kt` window still opens (it draws above the Settings window).
- **Order of entries unchanged.** Materials stays second under KeepThat, so `AddToBlizOptions` for the launcher runs in the same loop position.
- **Collapse.** Keep the already-written `Options.CollapseMaterials(dialog)`: clear root keys under `materials\001` before `dialog:Open` in `Options.Open` and `Options.OpenMaterial` (the latter then re-expands only its path through `SelectGroup`). The Settings-window panel hook for collapse is dropped, since that panel no longer has a tree.

## Risks / Trade-offs

- Players who used Materials only from the game's Settings window now take one extra click → the launcher explains why and opens the right page directly.
- `HideUIPanel(SettingsPanel)` during combat may be blocked on some clients → guarded; the `/kt` window still opens.
