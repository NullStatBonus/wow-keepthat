## Why

KeepThat shows no icon in the game's AddOns list (Menu > AddOns), unlike most addons. The game reads the icon from the TOC's `IconTexture` field.

## What Changes

- Add the KeepThat badge (`KeepThat/Media/icon.tga`, 64×64 32-bit TGA with alpha, the author's own art) and an `## IconTexture:` line pointing at it in both TOC files.

## Capabilities

### New Capabilities

### Modified Capabilities
- `settings`: adds the AddOns-list icon requirement.

## Impact

- `KeepThat/Media/icon.tga` (new), `KeepThat/KeepThat_Vanilla.toc`, `KeepThat/KeepThat_Camelot.toc`, `tests/test_smoke.lua`, `docs/test-plan.md`.
- Patch release 0.2.2 at archive.
