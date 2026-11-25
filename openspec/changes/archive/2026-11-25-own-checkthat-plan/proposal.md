# Proposal

## Why

KeepThat's in-game test plan lives in the CheckThat repository (`plans/full/keepthat.yaml`), apart from the code and log lines it matches (#33). A change that rewords a log line or adds a check cannot update the plan in the same commit, so the plan drifts. `docs/test-plan.md` is a second copy of the same checks, and some code comments already cite test plan sections that no longer exist (13, 13.2). AGENTS.md has no rule that keeps log lines, CheckThat facts, entry points and the plan in step.

## What Changes

- **The plan moves here.** `plans/keepthat.yaml` is a copy of CheckThat's `plans/full/keepthat.yaml` (31 steps in 10 sections, the same checks as `docs/test-plan.md`). It is the plan of record.
- **`docs/test-plan.md` becomes a pointer.** It says where the plan is, how to validate and run it, and that "test plan check 4.1" means step `kt.s4.1`. It holds no checks, so it cannot drift.
- **AGENTS.md gets a `## CheckThat` section** (the text from #33, reconciled with the Testing rules). The Documentation and Testing bullets that named `docs/test-plan.md`, `Check:` and `Log:` now name the plan and its YAML fields.
- **A new test, `tests/test_plan.lua`,** checks that step ids are unique and numbered in order and that every "test plan N.M" reference in the code, tests and docs names a step or section the plan has. The stale references are fixed.
- **Packaging and tooling.** `.pkgmeta` ignores `plans` and `build`; `.gitignore` ignores `build/`. `make plan` validates and compiles the plan with the sibling CheckThat checkout when it exists; `make test` and `make check` do not need it.

Out of scope (later work, #33 step 4): log lines, `CheckThat.Report` facts, `CheckThat.Entry` entries, `Integrations/CheckThat.lua`, the version-check first step, and turning player steps into automatic steps. The CheckThat side (removing its copies) is NullStatBonus/wow-checkthat#129.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No requirement changes (`skip_specs: true`).

## Impact

- **Code:** none in the shipped addon except two comments.
- **Tests:** new `tests/test_plan.lua`.
- **Docs:** `AGENTS.md`, `docs/test-plan.md`, `README.md`, `DESIGN.md`, `docs/contracts.md` (references), `CHANGELOG.md`.
- **Packaging:** `.pkgmeta`, `.gitignore`, `Makefile`.
- **Saved data:** no change.
- **Release:** patch, 0.6.1. The package content is the same as 0.6.0 except the version.
