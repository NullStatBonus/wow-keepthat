# Proposal

## Why

The in-game test plan (`plans/keepthat.yaml`, issue #33) now lives in this repository, but KeepThat gives CheckThat nothing to read except a few debug lines. Every step except a handful needs the player to judge the result, `ct.py validate` warns that the first step does not check the version under test, and `ct.py coverage` reports 3 of 12 commands, 0 of 9 settings and 0 of 106 requirements covered. This change targets requirement coverage first. Command and setting coverage rise where a converted step names its slash command. It is step 4 of issue #33: let CheckThat prove what the log, a fact or an entry can prove, so player steps remain only for drawing, sound, position and feel.

## What Changes

- New optional integration `KeepThat/Integrations/CheckThat.lua`. It holds every CheckThat call, each guarded and in `pcall`. On an error it turns itself off for the session and the debug report names the reason. It runs on both clients, has no toggle and no Integrations page row, and CheckThat is not added to `OptionalDeps` (CheckThat lists KeepThat, so KeepThat loads first). Both TOC files list it after `Integrations\Auctionator.lua`.
- A `version` entry that returns the KeepThat version as one number (major*10000 + minor*100 + patch). A new first plan step `kt.s1.1` calls it and checks `op: ge`. This clears the validate warning. The current "No Lua errors" step becomes `kt.s1.2`.
- Pure-function entries registered at `PLAYER_LOGIN` (never at file scope) for what a plan should call: classification, the count still needed, export contents (as a count and list name), a setting's value, an integration's state and whether this character's stock is counted. They are covered in a new `offline:` block of the plan.
- Facts reported with `CheckThat.Report("KeepThat", key, value)` once, where the code decides: export item count, leveling estimate copper, Profession Journal materials listed and a toast counter. Numbers are reported as numbers.
- New or stabilized debug lines at the decision points the plan checks: toast shown/skipped and the sound used, export written, settings window opened (page) and the Materials launcher, demo start and end, stock bank and mailbox counted, the tooltip line added or skipped once per item and path. Toggles log both directions, refusals and skips log too, and failures use `FAILED:`.
- Plan steps that a line, fact or entry proves become `auto: true` steps with required checks. Player steps remain for drawing, sound, position and feel. Steps and sections gain `covers:` so `ct.py coverage` reports requirement coverage.
- Docs: `docs/contracts.md` (the CheckThat API KeepThat relies on, the version encoding, every fact key and entry), `README.md` "Good to know" and the debug report, `docs/test-plan.md`. No new setting and no new slash command.

## Capabilities

### New Capabilities

- `checkthat-integration`: how KeepThat exposes evidence to CheckThat: the contained integration, the version entry, the entries, the facts and the plan-checked debug lines.

### Modified Capabilities

- `settings`: "Integrations on WoW Forever only in this version" gains an exception for the CheckThat integration, which also runs on Classic Era because the plan runs on both clients. "Debug report" scenario added: the report lists the CheckThat integration state.

## Impact

- Code: new `KeepThat/Integrations/CheckThat.lua`; one-line calls through `ns.CheckThat` and new `ns.Log.Record` lines in `UI/Toast.lua`, `UI/Tooltip.lua`, `Integrations/Auctionator.lua`, `Integrations/ProfessionJournal.lua`, `Integrations/Merchant.lua`, `Core/Stock.lua`, `Core/Slash.lua` and `Options/Options.lua`. Game calls stay in `Core/Adapter*.lua`; the integration needs none of its own.
- Both TOC files (`make check`).
- Plan: `plans/keepthat.yaml` gets a `facts` and an `errors` log source, the version step, the `offline:` block, `covers:` and the `auto` conversions. `kt.s1.1` is renumbered to `kt.s1.2`; past runs keyed by `kt.s1.1` no longer line up in `ct.py trend`.
- Tests: new `tests/test_checkthat.lua`; additions to the feature test files for each new log line.
- Players see no change. KeepThat works the same with CheckThat missing, old or present without a run.
- Version: minor bump to 0.7.0 (new capability, pre-1.0 rules).
