## 1. Plan

- [x] 1.1 Copy `plans/full/keepthat.yaml` from `../wow-checkthat` to `plans/keepthat.yaml`
- [x] 1.2 Validate it with `ct.py validate` from the KeepThat root (KeepThat's `openspec/specs`)
- [x] 1.3 Add `make plan` (validate and compile when the CheckThat checkout exists)

## 2. AGENTS.md

- [x] 2.1 Add the `## CheckThat` section from #33 with real `<` and `>` characters
- [x] 2.2 Reword the Documentation and Testing bullets to name the plan and its YAML fields, with no duplicate rules

## 3. Test plan document

- [x] 3.1 Replace `docs/test-plan.md` with a pointer to `plans/keepthat.yaml`
- [x] 3.2 Add `tests/test_plan.lua`: unique, ordered step ids; every "test plan N.M" reference resolves; break it, see it fail, restore
- [x] 3.3 Fix the stale references (sections 13 and 13.2) and update README.md and DESIGN.md

## 4. Packaging and release

- [x] 4.1 Ignore `plans` and `build` in `.pkgmeta`, and `build/` in `.gitignore`
- [x] 4.2 Set `## Version: 0.6.1` in both TOC files and write the `## 0.6.1` changelog section
- [x] 4.3 `make test` and `make check` pass
