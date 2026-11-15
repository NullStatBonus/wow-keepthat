# Recommendation coverage and reconciliation

Every approved recommendation and related review suggestion is accounted for below. Incorporated identifies the approved scope; implementation evidence and remaining manual checks are recorded below. DDT remains excluded. No normative requirement is satisfied solely by this table: the named delta or retained canonical requirement owns the behavior.

| ID | Recommendation | Disposition | Requirement / destination | Verification |
| --- | --- | --- | --- | --- |
| A1 | Spacing, font objects, neutral ink and native controls | Incorporated | shared-presentation / Local visual contract | Standalone install; missing controls |
| A2 | Semantic colors with visible labels; no brand-color conflation | Incorporated | shared-presentation / Meaningful color and readable content | Long content; category distinction |
| A3 | Black persistent surfaces, no decoration at alpha zero, independent dimming | Incorporated | shared-presentation / Independent visual dimming | Background off; new elements; upgrade |
| A4 | Compact 280×40 family, icons and variable height | Incorporated | loot-toast / Toast on looting a marked item | Long route or subtitle |
| A5 | Native tooltip chrome and coexistence; no duplicate suite framework | Incorporated | shared-presentation / Local visual contract; design.md | Missing control API; independent install |
| B1 | Home, feature pages, Appearance, Advanced, About | Incorporated | settings-interaction / Settings landmarks | Common landmarks; feature retention |
| B2 | Shared labels and disabled dependent controls with reasons | Incorporated | settings-interaction / Consistent control vocabulary | Disabled dependency |
| B3 | Accurate settings scope and immediate UI/CLI parity | Incorporated | settings-interaction / Settings scope and immediate parity | Two characters; scope switch; UI and CLI agree |
| B4 | Preserve domain pages and defaults | Retained with explicit regression coverage | settings / Settings pages; existing Materials and Integrations requirements | Feature retention; old saved data |
| C1 | Common verbs; old commands and bare behavior | Incorporated | slash-interface / Common command discovery | Legacy entry point; grouped help |
| C2 | Typed public keys, bounds, scope and refresh callbacks | Incorporated | slash-interface / Allowlisted setting registry; Initial public settings | Invalid mutation; read/write primary key |
| C3 | Case preservation, surplus-argument rejection, concise replies | Incorporated | slash-interface / Allowlisted setting registry | Preserve names; invalid mutation; single acknowledgement |
| C4 | Copyable logs and confirmed diagnostic-only clear | Incorporated | slash-interface / Common command discovery | Report clearing |
| C5 | Every new setting included in diagnostics and docs | Incorporated | existing settings / Debug report; tasks 4.4 and 5.5 | Report presentation; doc/check review |
| C6 | Public broad demo; focused previews retain integration tests | Incorporated | visual-preview / Broad synthetic demo; Focused visual previews | No side effects; repeat and restore; unknown kind |
| D1 | DDT compact banner, pinned explanations and purchase guards | Excluded by user | reference.md | No DDT files modified |
| D2 | CV selectable Warning/Toast, Warning default | Not applicable: CV-only amendment | reference.md | No invented CV controls |
| E1 | Safe demo/preview accepts with inert callbacks; live restore | Incorporated | visual-preview / Broad synthetic demo | No side effects; repeat and restore |
| E2 | Explicit Move/Done/Cancel; Escape rollback; lock; clamp; reset only position | Incorporated | visual-preview / Transactional Move mode | Done; Cancel or Escape; Locked; profile change |
| E3 | Retain normal toast mouse transparency or HUD row clicks | Incorporated | visual-preview / Transactional Move mode | Normal input regression and in-game checks |
| F1 | Shared runtime library or suite launcher | Deferred / out of scope | design.md / Goals and Decisions | Independent install; reconsider only with measured duplication |
| F2 | Cross-addon tooltip ordering integration | Deferred | design.md; shared-presentation retains coexistence | No coupling or sibling hooks; future integration requires separate change |
| F3 | Profile system unification and changed bare /cvn behavior | Rejected for this change | settings-interaction; slash-interface | Two characters; Legacy entry point |
| F4 | Old screenshot material links and truncation | Evaluate current build; no speculative redesign | shared-presentation / Meaningful color and readable content; tasks 5.3–5.4 | Long-label in-game review; retain current material improvements |
| F5 | Tests, captures, fallback, docs, TOCs and archive/version workflow | Incorporated | tasks.md sections 2 and 5; design.md / Validation | Runtime verification remains unchecked |

## Baseline and dependencies

The initial KeepThat change was archived as 2026-11-15-initial-keepthat before this preparation. Canonical settings and loot-toast are now the baseline. No active-change merge dependency remains. Explicit MODIFIED deltas replace old Home positioning and full-line toast color requirements; material/integration requirements remain canonical.

## Verification record

- Runtime implementation: implemented in this repository; automated verification passes. In-game verification and screenshots remain pending, as does the user-deferred archive workflow.
- Canonical specs: intentionally unchanged until implementation and normal sync/archive workflow.
- OpenSpec strict validation: PASS (`openspec validate cohesive-addon-presentation --strict --no-interactive`, 2026-11-15), no warnings. Planning artifacts complete according to `openspec status --change cohesive-addon-presentation --json`. Modified requirement names match canonical baseline; every delta requirement has scenarios.
- Browser visual is illustrative and predates CV style/demo amendments; written deltas control.

## Implementation verification (2026-11-15)

| IDs | Implementation / automated evidence | Remaining game evidence |
| --- | --- | --- |
| A1, A5 | Local v1 tokens and guarded font lookup; bundled Ace source recorded in docs/contracts.md; real Ace registry validates both TOCs in smoke tests | Native chrome, font/control fallback, standalone and third-party tooltip coexistence (§7.1, 4) |
| A2, A4, F4 | Neutral wrapped toast titles, labeled category words, fallback icon and measured-height stacking; presentation and wording tests; material detail quality names retained | Long localized labels and matching captures (§7.1, 4) |
| A3 | Black background and separate ink/background alpha; accent follows background; exact legacy-alpha migration; new/existing frame tests | 0/80/100 and scale 100/150 at matching UI scale (§7.3) |
| B1, B2 | Six ordered AceConfig pages; Appearance owns presentation; disabled dependency explanations and retained values; options and smoke tests | Navigation/readability (§7.1–2) |
| B3, C2 | Typed public registry shares UI/CLI effects; scope explanation in page content and confirmed scope switch; no copying; migration and parity tests | Two-character persistence and open-window scope changes (§7.7) |
| B4 | Material/integration code paths retained; full options, export, classification and integration suites pass | Search/stock/recipes/export/copy and optional states (§7.1) |
| C1, C3 | Common verbs, case-insensitive identifiers, preserved search case, rejected surplus/invalid input, single setter reply; slash/presentation/README tests | Chat output and help discoverability (§7.2) |
| C4 | Native diagnostic-only confirmation; tests prove request/cancel path leaves logs intact and accept retains settings | Popup Cancel/Escape and copyable report (§7.8) |
| C5 | Flattened migrated settings plus presentation runtime state in log; README, listing, contracts and manual plan updated | Inspect report (§7.8) |
| C6, E1 | Independent samples do not touch real toast entries/queue/dedup; private tooltip and isolated tint; repeat/expiry tests; legacy test entry points retained | All surfaces, disabled features, concurrent real loot, Shift and expiry (§7.5) |
| E2 | Transactional drag with native Done/Cancel, Escape, lock, clamping, position-only reset and scope cancellation; tests drive actual drag/Escape scripts | Screen edges, keyboard, combat and scope switch (§7.6–7) |
| E3 | Production toast factory remains mouse-transparent | Mouse-through (§7.6) |
| D1, D2, F1, F2, F3 | Exclusions/deferrals preserved; only this repository changed; no CV/DDT controls, shared runtime, sibling hooks or profile unification | None introduced |
| F5 | Both TOCs include Presentation; full make test/check and strict validation pass; no canonical sync/version/changelog/archive/commit/release performed | Captures and final in-game acceptance; workflow deferred by user |

Required checks: `make test` (23 Lua test files, 23 Python tests), `make check`, `openspec validate cohesive-addon-presentation --strict --no-interactive`, and `git diff --check`. No pre-existing check failures observed. The implementation is ready for in-game review, not certified by screenshots. `docs/test-plan.md` §7 is the handoff checklist; no in-game row above is marked complete without user evidence.

Test sensitivity: temporarily removing the legacy-alpha getter fallback made `tests/test_presentation.lua` fail as expected; the source was restored and the full suite rerun successfully.

User-requested preview refinement: random real catalog/routes material, native item content with cache fallback, realistic isolated skill/count data and one shared live/preview renderer. `tests/test_tooltip_preview.lua` verifies exact row/color parity, real recipe/guide metadata, private-hook isolation, cache refresh, repeat/expiry and unchanged feature/material toggles. In-game hover comparison and uncached-item rendering remain pending in docs/test-plan.md.

User-requested settings UX refinement: all six pages and profession/material details provide visible purpose context; scope appears only where relevant. Appearance has task-based sections and explicit surface preview actions; feature-off, lock and Move guidance follows current state. Integration descriptions explain each contribution, Advanced explains profile-switch consequences and the record/reproduce/copy workflow, and About provides navigation and grouped command discovery. Options tests verify scope/state updates and nested-page coverage; in-game readability review remains in docs/test-plan.md.

User-requested compact sizing: standalone default reduced from Ace’s 700×500 to 600×460; appearance sliders/action buttons use bounded widths and tint location choices share a compact row. Native resizing, scrolling and full-width explanatory text remain. Exact CVN size and in-game comparison remain unverified; see docs/test-plan.md. Full tests and required checks pass.

User-requested concise help: shortened page, scope, dependency, position, preview and troubleshooting copy using ASD-STE100 principles. Removed repeated leveling/profile notes. DESIGN.md records sentence limits, consistent terminology and concise copy examples. Existing scope/state tests and localization checks pass.
