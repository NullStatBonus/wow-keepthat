## Context

A–E were approved on 2026-11-15 with broad demo commands and CV Warning/Toast choice. This preparation changes specifications only. Don’t Do That is excluded. Runtime tasks remain unchecked. The browser sketch predates the amendments; normative delta requirements take precedence.

## Goals / Non-Goals

Goals: consistent visual roles and settings vocabulary, safe discoverable demonstrations, typed CLI access, accessible cues and deliberate positioning. Preserve gameplay, defaults, saved data, optional integrations and independent installation. Non-goals: suite launcher, new shared runtime library, global Blizzard reskin, DDT work, release or implementation in this pass.

## Decisions

1. Keep the existing renderer: AceConfig. Use standard controls and verify actual client source/templates before implementation; no new API availability is assumed by this spec.
2. Keep a versioned local style contract in each repo (shared contract version 1). Use 4-unit spacing and existing font objects; baseline toasts 280×40 with 28-unit icons, but grow for long copy. Use neutral content and small textual/symbolic semantic cues. Preserve item-quality titles on material detail pages.
3. UI and new get/set commands share a typed registry and refresh hooks. Public keys differ from storage keys; adapters normalize units at the boundary. Read existing command limits instead of duplicating them. Existing valid commands remain available.
4. Preview/demo use the real drawing components with injected synthetic state and inert side-effect callbacks. They must not enter production pin/buy/accept paths. Keep integration test commands separate. Do not persist samples or consume real deduplication/cooldowns. Restore current live state after the demo.
5. Move is a transaction: start snapshot, tentative drag, commit Done, restore Cancel/Escape. Scope change cancels. Existing unlocked CV title/Shift-drag shortcuts still save normally outside Move. All movement is blocked while locked.
6. New opacity controls separate surface and text/icon alpha. For KT old toastOpacity, preserve the effective alpha of both layers when splitting it; do not simply reset either to a brighter default. Black remains the default. Background alpha zero also hides decorative accents.
7. Keep existing settings scopes. KT retains shared Default settings with the existing character-profile opt-in. Material review/search/stock/recipe/export and integration behavior are retained.

## Reconciliation and conflicts

- The earlier initial-keepthat change is now archived as 2026-11-15-initial-keepthat. No dependency on an active initial change remains. Use canonical settings and loot-toast as the baseline; do not edit or rearchive the initial change.
- Settings pages and Loot toast position currently place appearance and movement on Home. The deltas relocate them explicitly rather than adding conflicting parallel requirements.
- The old mover saves during dragging and finishes on right-click. Transactional Move replaces its provisional-save semantics; right-click may remain a Done alias.
- loot-toast previously required the tooltip line in the same color. The delta preserves meaning while adopting a neutral title and color only on category words.

## Risks and migration

Long localized copy, absent native controls, combat constraints and stale SavedVariables require explicit handling. Preserve previous values, validate only new public input with the existing bounds, and use guarded adapter APIs. Do not infer client APIs from the browser preview. Add new files to both TOCs when implementation begins. Tooltip coexistence must preserve native and third-party content without sibling dependencies.

## Validation and rollout

Run OpenSpec strict validation now. Later implement using the existing plain-Lua harness for validation, aliases, migration, preview side effects and Move transactions. Run repository-required checks and capture in-game Home, Appearance, tooltip, notice/toast and prompt at matching UI scale, long text, missing integrations/APIs, alpha 0/80/100 and supported addon scales 100/150. Compare against coverage.md. Update README, listing where relevant, manual test plan, localization and debug reports. Only then follow the repository sync/archive/version workflow; canonical specs are deliberately not synced during this preparation.
