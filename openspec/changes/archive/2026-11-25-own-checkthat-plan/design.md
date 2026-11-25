# Design

## Decisions

- **The YAML is the plan of record; `docs/test-plan.md` is a pointer.** Three options were weighed:
  1. Keep both by hand. Two copies of 31 checks drift; this is the problem #33 reports.
  2. Generate the YAML from the Markdown with `ct.py from-md`. A fresh conversion of today's `docs/test-plan.md` matches the step text of `plans/full/keepthat.yaml` but drops its hand-tuned checks: log patterns, the `log-sequence` for 9.2, `clients` and `requires: dfl`. Every regeneration would lose them.
  3. Generate the Markdown from the YAML. Adds a generator for a document nobody needs once CheckThat shows each step on its card.
  Option 4, a pointer, has one copy and nothing to generate. It is chosen.
- **Step ids keep the old numbers.** `kt.s4.1` is check 4.1 of the old document, so existing references ("test plan check 4.1") stay meaningful. `tests/test_plan.lua` checks that each such reference resolves, which replaces the rule "keep section numbers unique and in order".
- **The test reads the YAML with Lua patterns.** CI has no CheckThat checkout and no YAML library. The test only needs `- id:` lines, which the plan writes in one fixed form. Full validation stays with `ct.py validate` (`make plan`).
- **The version warning stays for now.** `ct.py validate` warns that the first step does not check the version. CheckThat can check it only through a fact (`op: ge`) that KeepThat reports, which needs `Integrations/CheckThat.lua` (step 4 of #33). The AGENTS.md rule is kept so that step 4 adds it.
- **Reconciling the AGENTS.md text.** The proposed section said "a `Check:` in player words". The plan has no `Check:` line; it has `action.text`, `expect`, `reviewer` and `assertions`. The Testing bullet now names these fields, and the CheckThat section points to it instead of repeating it.
