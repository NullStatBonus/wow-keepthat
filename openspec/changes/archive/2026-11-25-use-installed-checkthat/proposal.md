# Proposal

## Why

AGENTS.md, the Makefile and the docs run CheckThat's tools from a sibling checkout (`CT ?= ../wow-checkthat`, its `.venv`, `luajit ../wow-checkthat/tests/replay_plan.lua`), and the plan needs a hand-written hooks file, `plans/keepthat.replay.lua` (#35). The installed CheckThat skills (0.20.1) now run `validate`, `compile`, `replay-flow`, `lines` and `offline` with no checkout, and replay another addon's plan with no hooks file. CheckThat's `docs/adopting.md` says never to point an addon's files at a CheckThat checkout.

## What Changes

- **`ct <command>` everywhere.** `make plan` calls the installed `ct` launcher (`CT ?= ct`) and runs the whole gate before a tester: `validate`, `compile` to `build/keepthat.ct`, `replay-flow`, `lines --addon-src KeepThat` and `offline`. It stops with a clear message when `ct` is missing. `make test` and `make check` still need no CheckThat.
- **AGENTS.md's CheckThat section** is the one from CheckThat's `docs/adopting.md`, merged with KeepThat's rules (facts, entries, the integration file, `OptionalDeps`, the Testing cross-reference). The contracts rule no longer asks to edit CheckThat's `tools/ct.py`.
- **No hooks file.** `ct replay-flow plans/keepthat.yaml` passes on both clients with no `--hooks`. `plans/keepthat.replay.lua` and every reference to it go.
- **Step ids stay.** `tests/test_plan.lua` accepts gaps in step and section numbers (still unique and increasing), so a removed step never forces a renumber.
- **A guard test.** `tests/test_plan.lua` fails when AGENTS.md, the Makefile, CONTRIBUTING.md, README.md, DESIGN.md or `docs/` point at a CheckThat checkout or the hooks file.
- **Docs.** `docs/test-plan.md`, `docs/contracts.md` (fake client limits measured with the installed 0.20.1), README.md and CONTRIBUTING.md name `ct`. `.gitignore` ignores `evidence/`, where `ct collect` now writes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Developer tooling only (`skip_specs: true`).

## Impact

- **Code:** none in the shipped addon.
- **Tests:** `tests/test_plan.lua`.
- **Docs and tooling:** `AGENTS.md`, `Makefile`, `.gitignore`, `README.md`, `CONTRIBUTING.md`, `docs/test-plan.md`, `docs/contracts.md`, `CHANGELOG.md`; `plans/keepthat.replay.lua` deleted.
- **Saved data:** no change.
- **Release:** patch, 0.7.1. Nothing changes in game.
