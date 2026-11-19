# Tasks

## 1. Rename the old-named profile

- [x] 1.1 Add `ProfileKey.Rename(db, oldKey)` to `KeepThat/Model/ProfileKey.lua` (design D1) and call it in `Core/Addon.lua` right after `Migrate` with the same old key, both before `Presentation.Migrate` (D2). Verify the `tests/test_core.lua` call-order case expects `profile migrate, profile rename, presentation`.
- [x] 1.2 Extend `tests/test_profilekey.lua` with real AceDB 40 (Forever stubs): (a) using the old profile: afterwards current is the new name with the same values and no old-named profile; (b) then toggling off and on (`SetProfile("Default")`, `SetProfile(db.keys.char)`) gives the same values; (c) on Default with an old-named profile: stays Default, profile moved, `SetProfile(new)` gives its values; (d) both names exist: nothing changes, current kept; (e) Era stubs: saved data deep-equal; (f) second load: nothing changes; (g) a failing `CopyProfile` (fake db): stays on the old profile, no half-made new profile, failure recorded. Verify `luajit tests/run.lua profilekey` passes.
- [x] 1.3 Mutation check: drop the `oldKey == new` guard; drop the "new profile exists" guard; skip `DeleteProfile`; call Rename before Migrate; drop the rollback. Verify each makes `make test` fail; restore.
  - The `oldKey == new` guard was redundant (equal names means the profile exists under the new name, which the "never overwrite" check already rejects); no test could fail, so it was removed. The other four mutations each failed a test.

## 2. Docs

- [x] 2.1 README Advanced bullet: replace the limit sentence with "On WoW Forever, a character that used its own settings before 0.4.3 keeps them, including after turning \"This character\" off and on." Verify `tests/test_readme.lua`.
- [x] 2.2 `docs/test-plan.md` §10 step 4: turning "This character" on again brings back the same values (Scale 150); add step 6 for a character that already had both profiles (left as is). `docs/contracts.md`: add the rename to the migration note. Verify `make test`.

## 3. Verification

- [x] 3.1 `make test` and `make check` pass.
- [ ] 3.2 (Not reported before publishing: the player asked to publish 0.4.4 on 2026-11-18 without an in-game result.) In game on WoW Forever with a character restored by 0.4.3: after 0.4.4 it keeps its settings; toggle "This character" off and on: same settings. Classic Era unchanged.

## Workflow follow-up

- Only when the player asks: `/opsx:archive`, bump to 0.4.4 with a CHANGELOG line, commit, PR, merge, tag, close #20.
