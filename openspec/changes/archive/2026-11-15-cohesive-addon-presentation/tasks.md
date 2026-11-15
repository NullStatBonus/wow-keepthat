## 1. Specification preparation

- [x] 1.1 Recheck current active/archive state and canonical requirements.
- [x] 1.2 Record A–E approval, demo amendment, CV style amendment and DDT exclusion.
- [x] 1.3 Evaluate each recommendation in coverage.md; write explicit deltas for overlapping requirements.
- [x] 1.4 Run strict OpenSpec validation and inspect artifact completeness; record results in coverage.md.

## 2. Implementation planning and standard controls

- [x] 2.1 Inspect actual Blizzard/Ace controls and fallback patterns; record the source and API contract measured.
- [x] 2.2 Map each new public key to actual stored values, units, validator, scope and refresh callback; document aliases and supported page/topic/kind names.
- [x] 2.3 Review coverage.md against every implemented requirement and scenario; resolve remaining implementation choices without expanding scope.

## 3. Presentation and settings

- [x] 3.1 Implement local visual tokens, neutral titles, readable semantic cues and long-content layout without global reskinning.
- [x] 3.2 Add approved settings landmarks, common labels, accurate scope and dependent-control explanations while preserving feature pages.
- [x] 3.3 Add independent opacity/scale where specified; migrate old alpha and preserve profiles, enabled states, colors and positions.
- [x] 3.4 Preserve material search, quality names, category toggles, stock/recipes/exports/copy link and optional integration states.

## 4. Commands and interactions

- [x] 4.1 Implement common verbs, grouped help and typed get/set registry; preserve bare and valid legacy commands.
- [x] 4.2 Implement broad safe demo and focused previews with no real side effects; preserve legacy test behavior.
- [x] 4.3 Implement Move/Done/Cancel/Escape, lock enforcement, position-only reset and scope-change cancellation.
- [x] 4.4 Update debug reports for every new setting and presentation state; ensure log clearing affects diagnostics only.

## 5. Verification and documentation

- [x] 5.1 Add meaningful harness coverage for invalid/missing/surplus input, aliases, UI/CLI parity, scope/migration, demo isolation and Move rollback.
- [x] 5.2 Run required repository checks and tests; record results and any existing failures separately.
- [ ] 5.3 Verify in game: all owned surfaces, long localized content, missing APIs/integrations, combat interactions, opacity 0/80/100, scale and locked/unlocked movement.
- [ ] 5.4 Capture comparable screenshots and complete every coverage.md verification row.
- [x] 5.5 Update README, applicable listing text, manual test plan, localization, debug reports and both TOCs for new files.
- [ ] 5.6 After implementation and validation, follow repo sync/archive/version/changelog rules; do not commit an active change.

Implementation record (2026-11-15): registry and source contracts are in `docs/contracts.md`; automated acceptance is in `tests/test_presentation.lua` plus existing suites. Tasks 5.3–5.4 require the user’s game clients and screenshots (`docs/test-plan.md` §7). Task 5.6 is intentionally deferred: the user explicitly prohibited archive, commit and release; canonical sync/version/changelog remain untouched.
