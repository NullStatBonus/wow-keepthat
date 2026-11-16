# Tasks

## 1. AddOns list icon

- [x] 1.1 Add `KeepThat/Media/icon.tga` and `## IconTexture: Interface\AddOns\KeepThat\Media\icon.tga` to both TOCs; verify in `tests/test_smoke.lua` (both TOCs name the same icon, the file exists and is a 64×64 32-bit TGA) and `make check`.
- [x] 1.2 Add a manual check to `docs/test-plan.md` section 6; verify `make check`.
- [ ] 1.3 In game on Classic Era and Forever: the AddOns list shows the badge next to KeepThat.

## Workflow follow-up

- Archive, bump both TOCs to 0.2.2 with a CHANGELOG line, commit, PR, merge, tag `v0.2.2`.
