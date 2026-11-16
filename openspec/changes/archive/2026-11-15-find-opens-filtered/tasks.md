# Tasks

## 1. /kt find opens filtered Materials

- [x] 1.1 Add `Options.OpenSearch(query, found)` in `KeepThat/Options/Options.lua`: set the Materials search to the query, collapse professions, expand only professions with a visible match, open the window on Materials; verify in `tests/test_options.lua` (search set, only matching professions expanded, Materials selected).
- [x] 1.2 In `KeepThat/Core/Slash.lua`, several matches call `deps.openSearch(query, found)` instead of listing in chat; when none of them is visible, answer with the Home-checkbox sentence; verify in `tests/test_slash.lua` (several opens search with no chat lines; all hidden explains; breaking either fails).
- [x] 1.3 Update `README.md` (`/kt find` row) and `docs/test-plan.md` (section 6 step 15 and section 8 step 5); verify `make test` (README command check) and `make check`.

## Workflow follow-up

- Archive into the unreleased 0.2.1 (no new version), update the 0.2.1 CHANGELOG line, push to PR #5.
