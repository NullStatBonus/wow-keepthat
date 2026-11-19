# Tasks

## 1. Libraries to Ace3 ac3d122

- [x] 1.1 Download the WoWUIDev/Ace3 `ac3d122` tarball into a fresh scratch directory. Copy exactly the files listed under `KeepThat/Libs` (Lua and XML, same paths) over the current ones, and keep `LICENSE-Ace3.txt` and the `embeds.xml` module set (AceHook stays out). Verify: `find KeepThat/Libs -type f | sort` lists the same paths as before, and `git diff --stat KeepThat/Libs` touches only AceDB-3.0.lua, AceConfigDialog-3.0.lua and the ColorPicker, Heading, Icon and Label widgets, plus any XML or LICENSE files that differ upstream.
- [x] 1.2 Hash-compare every file KeepThat and `../wow-closest-vendor/ClosestVendor/Libs` both ship (LibStub, CallbackHandler, AceGUI and widgets, AceConfigRegistry, AceConfigDialog) with `shasum -a 256`. Verify: every pair is identical. Also hash every KeepThat lib file against the tarball: all identical, so there are no local patches.
- [x] 1.3 Check the MAJOR and MINOR of each module in the shipped files. Verify: AceDB-3.0 40, AceConfigDialog-3.0 93, ColorPicker 29, Heading 21, Icon 22, Label 29, AceGUI-3.0 41, AceConfigRegistry-3.0 22, CallbackHandler-1.0 8, LibStub 2. The others are unchanged from r1403.
- [x] 1.4 Rewrite `KeepThat/Libs/VERSIONS.txt` in the shared provenance format (design D5): upstream URL, full commit hash and retrieval date, each module with MAJOR and MINOR, the license file, "Local patches: none", and the update steps. Check that `THIRD_PARTY.md` still describes it correctly. Verify: every minor in the file matches task 1.3.
- [x] 1.5 Extend the client stubs `tests/test_core.lua` `loadAceDB` uses for AceDB 40 (`UnitNameUnmodified`, `strlenutf8`, `RegionalUniqueNamesEnabled`, `C_GameRules.IsGameRuleActive`, `Enum.GameRule`), set up as Classic Era by default. Verify: `make test` passes with the new AceDB, and the existing saved-data checks in `test_core.lua` still pass.

## 2. Profile choice survives the Forever character key

- [x] 2.1 Add `A.LegacyCharacterKey()` to `KeepThat/Core/Adapter.lua` (design D2): `UnitName("player") .. " - " .. GetRealmName()`, guarded and in `pcall`, nil when either is missing or empty. Test it in `tests/test_adapter.lua`. Verify: the test covers a realm with a space ("Argent Dawn" kept as is), a missing `GetRealmName`, and an empty name.
- [x] 2.2 Add `KeepThat/Model/ProfileKey.lua` with `ns.ProfileKey.Migrate(db, oldKey)` following design D4, and list it in both TOC files at the same position in `Model`. Verify: `make check` passes.
- [x] 2.3 Call it in `Core/Addon.lua` `OnInitialize` right after `AceDB:New` and before `ns.Presentation.Migrate(self.db.profile)`, passing `ns.Adapter.LegacyCharacterKey()`. Verify: a `test_core.lua` case that records call order shows the migration runs before the presentation upgrade, and `tests/test_smoke.lua` (fake db with no `sv`) still passes.
- [x] 2.4 Add `tests/test_profilekey.lua`, using the real shipped AceDB 40 through a Forever-shaped stub (`RegionalUniqueNamesEnabled` true, `UnitNameUnmodified` returning a name and a surname). Cover these cases:
  - (a) An old-key per-character profile with custom values: the profile choice and values survive, and a second character stays on Default.
  - (b) A second run, after the player switched back to Default: it stays Default.
  - (c) Era-shaped stubs: `KeepThatDB` is deep-equal before and after.
  - (d) A choice already made under the new key: it is not overwritten.
  - (e) An older AceDB, as a fake db with `keys.char` equal to the old key: no change.
  - (f) An invalid profile name: no Lua error, and the profile is unchanged.

  Verify: `luajit tests/run.lua profilekey` passes.
- [x] 2.5 Mutation check (repo rule): break the code once at a time and confirm a test fails each time:
  - drop the `oldKey == new` early return;
  - drop the "current is Default" guard;
  - drop the clearing of `profileKeys[oldKey]`;
  - move the call after `Presentation.Migrate`;
  - use `A.PlayerIdentity` for the old key.

  Verify: each mutation makes `make test` fail. Restore the code afterwards.
- [x] 2.6 Update the docs:
  - `docs/contracts.md`: a dated section on AceDB's character key per client, both minors, and what KeepThat stores per character (profile choice only).
  - `docs/test-plan.md`: a new `## 10. Library update and Forever profile`, holding the Forever per-character-profile carry-over and the known limit that turning "This character" off and on starts a new empty profile.
  - `README.md` "Good to know": add the same limit only if the README lists profile behavior.

  Verify: `make test` passes (test-plan numbering and `test_readme.lua`).

## 3. Integration checks

- [x] 3.1 Run `make test` and `make check`. Verify: both pass with no warnings.
- [ ] 3.2 (Not reported before publishing: the player asked to publish 0.4.3 on 2026-11-18 without an in-game result.) Run the manual smoke test on Classic Era and on WoW Forever, with KeepThat, Don't Do That and Closest Vendor all installed:
  - open each addon's settings window;
  - `/reload`;
  - visit a merchant.

  On Forever, also run `docs/test-plan.md` section 10 with a character that had "This character" on under 0.4.2. Verify: no Lua errors (BugSack or `/console scriptErrors 1`), and the character profile carries over.

## Workflow follow-up

- Archive with `/opsx:archive`. At archive, bump both TOCs 0.4.2 -> 0.4.3 and add `## 0.4.3` to `CHANGELOG.md`. That section has one line saying Forever characters keep their own settings, and one line on the color picker fix on WoW Forever, worded to match what players see (design, Risks).
- Commit, open the PR, tag `v0.4.3` after merge (see `docs/publishing.md`).
- File a GitHub issue for the known limit: turning "This character" off and on after migration starts a new empty profile.
