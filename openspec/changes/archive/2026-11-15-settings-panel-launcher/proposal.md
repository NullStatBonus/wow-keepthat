## Why

With the full Materials tree inside the game's Settings window (Esc > Options > AddOns > KeepThat), switching from Materials to any other KeepThat page froze the game for about 77 seconds. This was measured in game on WoW Forever with only KeepThat enabled. The same switch in the standalone `/kt` window is instant. The time is not spent in KeepThat's redraw (~160–177 ms) or in Ace releasing the panel (0 ms), so the cause sits in the Settings window's handling of that panel. The fix is to keep the large tree out of that window. Separately, professions under Materials stay expanded for the whole session once opened, so the list rarely starts tidy.

## What Changes

- In the game's Settings window, the Materials entry becomes a short launcher page: one line about what Materials holds and an **Open KeepThat** button. The button closes the Settings window and opens the standalone `/kt` window on Materials. Home, Integrations, Appearance, Advanced and About stay in the Settings window unchanged.
- The `/kt` window keeps the full Materials tree, search, material pages and exports exactly as before.
- Every profession under Materials starts collapsed each time the settings open: in the `/kt` window when it opens, and in the Settings-window panel. Jumping to a material from `/kt find` still opens that one profession.

## Capabilities

### New Capabilities

### Modified Capabilities
- `settings`: Settings pages (Materials in the game's Settings window is a launcher) and Materials review (professions start collapsed).

## Impact

- `KeepThat/Options/Options.lua`: registers a separate launcher options table for the Settings-window Materials entry; `Options.CollapseMaterials` runs on open.
- `KeepThat/Core/Adapter.lua` (or an existing `Adapter_*` file): a guarded call that closes the game's Settings window.
- `tests/test_options.lua`: launcher registration, button behaviour and collapse.
- Docs: `README.md` (settings pages, "Good to know"), `docs/test-plan.md` (new manual section). No saved-data change, no new setting.
- Patch release (0.2.1) at archive.
