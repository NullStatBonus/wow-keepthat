# Tasks

## 1. Sound list and adapter

- [x] 1.1 Add `Model/Sounds.lua` (design D1, D2): ten entries in picker order with stable keys, `L[]` labels and kit IDs; `Resolve`, `Effective`, `Play` (None no-op, fallback to default when unresolved or `willPlay` false). Add it to both TOC files in the same position; verify `make check` passes.
- [x] 1.2 Add `Core/Adapter_Sound.lua` (D3): guarded `PlaySound`, `PlaySoundFile`, `SoundPacks` (LibSharedMedia `HashTable("sound")`, minus "None", nil when absent); channel limited to Master/SFX. Add to both TOCs after `Adapter_Merchant.lua`; verify `make check`.
- [x] 1.3 Add `tests/test_sounds.lua` with a fake adapter: list order and count; Resolve for a kit key, a pack key, an unknown key and a pack key with no packs; Effective returns the default for a missing pack; Play of None calls nothing; Play of a missing pack plays 5274; `willPlay` false falls back to the default; no play function returns false without error. Verify each test fails when its branch is broken, then `make test` passes.
- [x] 1.4 Extend `tests/test_adapter.lua`: `SoundPacks` returns nil without LibStub, nil when LibStub lacks the library, a table from a fake library; `PlaySound` returns nil when the global is missing and passes Master for an unknown channel. Verify `make test`.
- [x] 1.5 Record the ten kit IDs, file names and the two builds checked (SoundKitEntry 1.15.9.70576 and 1.60.1.70938, community listfile) in `docs/contracts.md`, and that LibSharedMedia is read only through `HashTable`/`Fetch`-style lookup in the adapter; verify the table matches `Model/Sounds.lua`.

## 2. Toast plays the sound

- [x] 2.1 Add defaults `toastSound = "auction"`, `toastSoundChannel = "Master"` in `Core/Defaults.lua`; verify `tests/test_core.lua` (or the defaults test) asserts both.
- [x] 2.2 In `UI/Toast.lua` play the sound on acceptance in `Toast.Handle` with a 2-second cooldown (D4); count merges stay silent; nil time plays without recording.
- [x] 2.3 Play the chosen sound once per `Toast.Demo` call without touching the real-loot cooldown.
- [x] 2.4 Extend `tests/test_toast.lua` with a fake `Sounds.Play` counter: first pickup plays once; count merge silent; toast off silent; five items in one second play once, and ticking past `SHOW` so toasts 4 and 5 appear adds no play; a pickup 10 s later plays; None plays nothing; Demo plays once each call while toast is off and does not block the next real-loot sound. Verify each assertion fails when its code path is broken, then `make test`.
- [x] 2.5 Add a `sound packs = <count>|none` line to the Presentation section of `/kt log` (`Debug/Log.lua`) and confirm `toastSound`/`toastSoundChannel` appear under Settings; extend `tests/test_log.lua`; verify `make test`.

## 3. Appearance pickers

- [x] 3.1 Add Sound and Sound channel `select` controls after Scale in Appearance > Loot toast (D5): function-built `values` and `sorting` (None, the ten, then packs alphabetically as `L["%s (sound pack)"]`), `get` via `Sounds.Effective`, `set` saves and plays once (not for None), disabled when the toast is off; extend the toast-off note to mention sound. Verify in `tests/test_options.lua`: order, pack label, missing pack shows `auction` without changing the saved key, set plays once, channel values Master and Sound effects.
- [x] 3.2 Add every new player-facing string to `Locales/enUS.lua`; verify `tests/test_locale.lua` passes.
- [x] 3.3 Ask Codex to review the Loot toast group layout (two new dropdowns, labels, disabled state, help note) and apply its findings; record the outcome in the change.
  - Codex (2026-11-18): keep both dropdowns after Scale under the Loot toast header, visible and disabled while the toast is off. Applied: Sound hover says "Choosing a different sound previews it once" (AceGUI does not call set when the current choice is clicked again); the toast-off note no longer promises Move (Lock position can disable it): "You can still preview the toast."; Sound channel uses the default width; the code comment says packs registered while the page is open appear on the next refresh.

## 4. Documentation

- [x] 4.1 README: Loot toast section (sound, default Auction open, None, one sound per burst, Master/Sound effects, sound packs when LibSharedMedia is present) and the Appearance bullet; leave the `/kt set` key list unchanged; verify `tests/test_readme.lua` passes.
- [x] 4.2 `docs/listing.md`: add the sound to the Loot toast bullet.
- [x] 4.3 `docs/test-plan.md` §3: new numbered checks continuing after 10 — default sound on first pickup; count merge silent; five-item burst one sound; None; each of the ten sounds heard via the picker on Era and Forever; Master heard with game sound effects off, Sound effects silent then; with a LibSharedMedia sound pack installed, pick it, then disable that addon and confirm Auction open plays and no error; Preview plays the sound with the toast off.

## 5. Integration check

- [x] 5.1 Run `make test` and `make check`; both pass.
- [x] 5.2 In game on Era and Forever, run the new test plan §3 checks and `/kt log`; record results (and any kit that fails) in `docs/contracts.md`.

## Workflow follow-up

- `/opsx:archive`: sync specs, bump both TOCs to 0.4.0, add the `## 0.4.0` CHANGELOG line.
- Comment on issue #15 that the sound shipped and the font choice was split off.
