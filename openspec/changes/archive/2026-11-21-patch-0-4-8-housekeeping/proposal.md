# Proposal

## Why

A review of the open issues on 2026-11-21 found four housekeeping items with no player-visible bug: workflow files that a fresh clone does not get (#28), a test-file rule the repository does not follow (#26), a manual test plan written in the old format (#27), and a library-version question between the three sibling addons (#14). The user asked for a patch release that clears them (release 0.4.8).

## What Changes

- **Track the OpenSpec workflow files (#28).** `.gitignore` ignored all of `.claude/`, so `.claude/skills/` and `.claude/commands/`, which AGENTS.md points to, were missing from a clone. Now those two folders are tracked; everything else in `.claude/` stays ignored. `.pkgmeta` already keeps `.claude` out of the package.
- **Test-file rule matches the repository (#26).** AGENTS.md said every module has its own `tests/test_<module>.lua`. Now it says where each module's tests live: its own file, or the file of the feature it serves, and it names those area files. `Debug/Export.lua`, the only module with no test at all, gets `tests/test_export.lua`.
- **Test plan in the one-action format (#27).** Sections 1–12 of `docs/test-plan.md` move to the format of section 13: one player action, a `Check:` line in player words, and a `Log:` line for the reviewer where a log line proves the result. Checks that unit tests already prove, and upgrade checks for 0.4.2–0.4.6, leave the plan.
- **Ace3 alignment confirmed (#14).** KeepThat, Don't Do That and Closest Vendor all embed Ace3 `ac3d122` with AceConfigDialog-3.0 minor 93; every Lua file the three share is byte-identical (sha256). KeepThat's `Libs/VERSIONS.txt` already records commit, module minors, license, patches and update procedure. No library change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No requirement changes (`skip_specs: true`).

## Impact

- **Code:** none in the shipped addon.
- **Tests:** new `tests/test_export.lua`.
- **Docs:** `AGENTS.md`, `docs/test-plan.md`, `.gitignore`, `CHANGELOG.md`.
- **Saved data:** no change.
- **Release:** patch, 0.4.8, by the user's request. The package content is the same as 0.4.7 except the version.
