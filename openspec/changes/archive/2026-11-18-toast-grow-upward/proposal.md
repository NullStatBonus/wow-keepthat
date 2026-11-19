# Proposal

## Why

Loot toasts stack downward from the saved position and seem to pop in and out: the fade-in is 0.15 s, the fade-out only the last second, and when a toast leaves the others jump into its place. The player asked for toasts that rise from the position and fade on a timer.

## What Changes

- The newest toast shows at the saved position; older toasts move up above it (previously each new toast went below).
- Toasts glide to their new place (about 0.2 s per slot) instead of jumping; a toast leaving never moves the others.
- Gentler timing within the same 4-second life: fade in over 0.3 s, fade out over the last 1.5 s.
- The Toast position help text says older toasts appear above the first.
- Replaces the old behavior for everyone; no new setting. Patch release 0.4.2.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `loot-toast`: "Toast on looting a marked item" (gradual fade in and out) and "Toasts stay out of the way" (stack upward from the saved position, glide instead of jump).

## Impact

- `KeepThat/UI/Toast.lua` (Position, placement in Tick/startNext/Demo/Refresh, fade constants, frame Place interface), `KeepThat/Options/Options.lua` (position help text), `KeepThat/Core/Defaults.lua` (comment).
- Tests: `tests/test_toast.lua`.
- Docs: README (Loot toast paragraph), `docs/test-plan.md` §3.
