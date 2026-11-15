## Why

Paul approved the shared addon experience A–E on 2026-11-15, retaining broad `demo` commands and adding Closest Vendor Warning/Toast presentation choice. KeepThat needs explicit, testable requirements for that design rather than implementation inferred from a mockup.

## What Changes

- Introduce local shared visual tokens, accessible semantic cues and native-control-first presentation.
- Organize settings around Home, feature pages, Appearance, Advanced and About; retain the current renderer and saved scope.
- Add explicit settings/status/help/preview and allowlisted get/set commands while preserving valid legacy commands.
- Keep demo as a broad synthetic visual test; separate it from integration test commands.
- Provide deliberate Move/Done/Cancel, independent opacity, position-only reset, and regression requirements.
- Retain material review, optional integrations, category colors and existing gameplay defaults.

## Capabilities

### New Capabilities
- `shared-presentation`: Local style contract, semantic cues and resilient content layout.
- `settings-interaction`: Common settings landmarks, scope and safe editing behavior.
- `slash-interface`: Common verbs and typed public setting registry.
- `visual-preview`: Broad demos, focused previews and transactional positioning.


### Modified Capabilities
- `settings`: Appearance page, settings parity, Move workflow and sample visuals.
- `loot-toast`: Neutral title and category-specific color semantics.

## Impact

Spec preparation only; runtime changes are future unchecked tasks. No new shared runtime dependency, no Don’t Do That changes, no canonical sync, version bump, release or commit in this pass. Read `design.md`, `coverage.md` and `reference.md` before implementation.
