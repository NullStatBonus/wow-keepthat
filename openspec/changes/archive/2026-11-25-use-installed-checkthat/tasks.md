## 1. Tooling

- [x] 1.1 Install the skills with `make install-skill BIN_DIR=$HOME/bin` in the CheckThat checkout; confirm `ct` is on PATH
- [x] 1.2 `make plan` runs `ct validate`, `ct compile`, `ct replay-flow`, `ct lines --addon-src KeepThat` and `ct offline`; stops with a message when `ct` is missing
- [x] 1.3 `.gitignore` ignores `evidence/`

## 2. Hooks file

- [x] 2.1 `ct replay-flow plans/keepthat.yaml` passes on both clients with no hooks file
- [x] 2.2 Delete `plans/keepthat.replay.lua` and every reference to it

## 3. AGENTS.md and docs

- [x] 3.1 Replace the CheckThat section with the one in CheckThat's `docs/adopting.md`, merged with KeepThat's rules
- [x] 3.2 Update `docs/test-plan.md`, `docs/contracts.md`, README.md and CONTRIBUTING.md to name `ct`

## 4. Tests

- [x] 4.1 `tests/test_plan.lua` accepts gaps in step and section numbers; break it, see it fail, restore
- [x] 4.2 `tests/test_plan.lua` fails when a tracked doc or the Makefile points at a CheckThat checkout or the hooks file; break it, see it fail, restore
- [x] 4.3 `ct offline plans/keepthat.yaml` passes 7 of 7

## 5. Release

- [x] 5.1 Set `## Version: 0.7.1` in both TOC files and write the `## 0.7.1` changelog section
- [x] 5.2 `make test`, `make check` and `make plan` pass
