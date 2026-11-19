# Tasks

## 1. Toast motion and timing

- [x] 1.1 `Toast.Position(index, entries)`: offset upward by the heights of the newer entries (index+1..n); mover and BeginMove use the anchor (no offset). Verify in `tests/test_toast.lua`: one toast at the anchor; with three, the oldest is two spacings above, the newest at the anchor.
- [x] 1.2 Glide: each entry keeps its current offset; a new entry starts at its target, existing entries move toward theirs at one spacing per 0.2 s during Tick; position changes and Refresh snap. Frame interface becomes `Place(point, x, y)`. Verify in tests: a new toast arriving moves the older one up gradually (part way after 0.1 s, there after 0.2 s); the oldest leaving does not move the others.
- [x] 1.3 Timing: `FADE_IN = 0.3`, `FADE = 1.5`, `SHOW` stays 4. Verify Alpha(0.15) = 0.5, Alpha(3.25) = 0.5, Alpha(4) = 0 in tests.
- [x] 1.4 Position help text: "Select Move to place the newest toast. Older toasts appear above it. Reset position changes only the position."; fix the Defaults.lua comment. Verify `make test` (locale test).
- [x] 1.5 Codex reviews the motion and timing (visual change) and its findings are applied or reported.
  - Codex (2026-11-18) kept the linear glide, stationary entrance and 0.3 s / 1.5 s fades. Applied all five findings, each with a test: same-frame arrivals start in their own places (no overlap in a burst); the gap uses the anchor edge (TOP: upper panel height, BOTTOM: lower, else half of each) so wrapped toasts never overlap; Refresh keeps current places instead of finishing a glide; real toasts hidden behind samples do not age, so they still fade in; frames skip re-anchoring when their place is unchanged.

## 2. Docs and verification

- [x] 2.1 README Loot toast paragraph and test plan §3 check 9 describe the upward stack and gradual fade; add a check for the glide. Verify `tests/test_readme.lua`.
- [x] 2.2 `make test` and `make check` pass.
- [ ] 2.3 In game on both clients: toasts rise from the saved position, glide, fade in and out gently; Move and /kt demo still place correctly.
  - Not reported before publishing: the player asked to publish 0.4.2 on 2026-11-18 without an in-game result.

## Workflow follow-up

- Only when the player asks: `/opsx:archive`, bump to 0.4.2 with a CHANGELOG line, commit, PR, merge, tag.
