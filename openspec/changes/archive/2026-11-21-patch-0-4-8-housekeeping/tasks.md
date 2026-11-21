# Tasks

## 1. Workflow files (#28)

- [x] 1.1 Change `.gitignore` so `.claude/skills/` and `.claude/commands/` are tracked and the rest of `.claude/` stays ignored
- [x] 1.2 Check the tracked files for local paths, emails or tokens

## 2. Test-file rule (#26)

- [x] 2.1 Map every TOC file to the test file that covers it
- [x] 2.2 Reword the AGENTS.md rule to name the area files and the Data/ rule
- [x] 2.3 Add `tests/test_export.lua` for `Debug/Export.lua`; break it, see it fail, restore

## 3. Test plan (#27)

- [x] 3.1 Rewrite sections 1–12 of `docs/test-plan.md` in the one-action `Check:`/`Log:` format
- [x] 3.2 Remove checks that unit tests prove and checks that need old versions; keep section numbers unique and in order

## 4. Ace3 (#14)

- [x] 4.1 Compare sha256 of KeepThat's `Libs/` files with the Closest Vendor and Don't Do That copies

## 5. Release

- [x] 5.1 Set `## Version: 0.4.8` in both TOC files and write the `## 0.4.8` changelog section
- [x] 5.2 `make test` and `make check` pass
