# Tasks

Phases follow design D9. Phase 1 is groups 1 and 2 and can ship alone. Groups 3 to 9 are phase 2 (entries) and phase 3 (lines, facts and step conversion), split by plan section so that each group lands its line, fact or entry together with the plan step that checks it. Every new behavior gets a test that is first seen to fail with the behavior broken, then to pass (AGENTS.md Testing).

## 1. Phase 1: CheckThat integration

- [x] 1.1 Add `ns.Adapter.LoggedIn()` to `KeepThat/Core/Adapter.lua` (guarded `IsLoggedIn` in `pcall`, nil when missing) with a case in `tests/test_adapter.lua`; verify `luajit tests/run.lua adapter` passes
- [x] 1.2 Create `KeepThat/Integrations/CheckThat.lua`: Gate registration `checkthat` with `anyClient = true` and `detect` on the `CheckThat` global; `ns.CheckThat.Report(key, value)` wrapper that ignores a false return and calls `ns.Integrations.Fail("checkthat", err)` only on an error (D1, D2); entry registration at `PLAYER_LOGIN` via `ns.Listen` on its own `addon:NewModule("CheckThat", "AceEvent-3.0")`, never on the addon object, or at once when `LoggedIn()` is true (D4); `[checkthat] entries registered: <n>`. Verify by reading that it makes no `C_*`, frame or unit call
- [x] 1.3 List `Integrations\CheckThat.lua` after `Integrations\Auctionator.lua` in `KeepThat/KeepThat_Vanilla.toc` and `KeepThat/KeepThat_Camelot.toc`; leave `OptionalDeps` unchanged; verify `make check` passes
- [x] 1.4 Write `tests/test_checkthat.lua` with a fake `CheckThat`: missing global, global without `Entry`, `Report` returning false (stays working), `Report` raising (fails once, `[checkthat] FAILED:` in the report, no later calls), registration deferred to `PLAYER_LOGIN`, the Gate's own `PLAYER_LOGIN` start still running after the CheckThat integration started, Classic Era start, and no Integrations page row. Break each guard once and see the test fail; verify `luajit tests/run.lua checkthat` passes
- [x] 1.5 Add a `/kt log` case to `tests/test_log.lua` that the "Integrations:" block lists `checkthat`; verify it passes
- [x] 1.6 Document the CheckThat contract in `docs/contracts.md` (new "CheckThat" section): `API_VERSION` 2, `Report` and `Entry` signatures and return values, name and value limits, 30 facts a second, 300 lines kept, the `entry.<name>=` result format, and the version encoding; verify against `../wow-checkthat/docs/features.md`
- [x] 1.7 Add to `README.md` (debug report and "Good to know") that the report lists CheckThat, and that the CheckThat support runs on both clients with no setting; leave `docs/listing.md` unchanged (nothing a player sees); verify `luajit tests/run.lua readme` passes

## 2. Phase 1: Version entry and first plan step

- [x] 2.1 Add the `version` entry (D3): parse `ns.version` to `major*10000 + minor*100 + patch`, nothing when unknown or unparsable; unit cases for 0.6.1 (601), 0.7.0 (700), 1.2.3 (10203), "unknown" and "0.7" in `tests/test_checkthat.lua`; verify it fails with the encoding broken, then passes
- [x] 2.2 Add `logs.facts` and `logs.errors` to `plans/keepthat.yaml`, insert the auto step `kt.s1.1` "KeepThat version" from design D3, and renumber "No Lua errors" to `kt.s1.2` with a diagnostic `errors` check `pattern: "%[KeepThat%]"`; verify `make plan` prints no version warning and `luajit tests/run.lua plan` passes
- [x] 2.3 Update `docs/test-plan.md` only if its text names step numbers it no longer matches; verify `luajit tests/run.lua plan` passes
- [x] 2.4 Replay the plan in the fake client: `luajit ../wow-checkthat/tests/replay_plan.lua build/keepthat.ct`; verify kt.s1.1 settles as auto

## 3. Phase 2: Entries and the offline block

- [x] 3.1 Add an `offline:` block to `plans/keepthat.yaml` (toc `wow-keepthat/KeepThat/KeepThat_Vanilla.toc`) that fires `ADDON_LOADED` (`KeepThat`) and `PLAYER_LOGIN` and then calls `version`; verify with `../wow-checkthat/.venv/bin/python ../wow-checkthat/tools/ct.py offline plans/keepthat.yaml`. If AceAddon does not start in the fake client, record why in design.md and open a CheckThat issue before going on
  - Blocked: the fake client does not follow `embeds.xml`, so AceAddon never loads (design "Implementation notes"). Recorded in design.md; the CheckThat issue is drafted for the maintainer to file.
- [x] 3.2 Add the entries `classify`, `needed`, `exportCount`, `setting`, `integration` and `stockCounted` (design D4 table), each side-effect free, scalar, at most 120 characters, no character names, and each body in `pcall` that records `ns.Log.Failure("checkthat", "entry <name>: ...")` and returns `error: ...` on an error. Add `Materials` and `ListName` to `ns.AuctionatorExport`. Add unit tests in `tests/test_checkthat.lua` against fake context and settings, including a check that a call changes no saved variable; verify each fails when its source is stubbed wrong, then passes
- [x] 3.3 Cover the entries in the `offline:` block (`classify` Arcanite Bar 12360, `setting` for one public key, `integration checkthat`); verify `ct.py offline` passes
  - Blocked by 3.1: the block is written and passes only with a local TOC that expands `embeds.xml` and a copy without `covers:`.
- [x] 3.4 Document each entry (name, args, returns, unknown result) in `docs/contracts.md`; verify the names match `tests/test_checkthat.lua`

## 4. Section 2 (Tooltip line) and section 4 (Icon mask)

- [x] 4.1 Add `[tooltip] line added <itemID> via <path>` (once per item and path per session) and `[tooltip] line skipped <itemID>: already on this tooltip` (once per item) in `UI/Tooltip.lua`; test in `tests/test_tooltip.lua` that 50 refreshes write one line; verify it fails with the once-guard removed
- [x] 4.2 Add `[merchant] tinted <n> of <m> on page <p>` and `... on buyback`, once per page shown, in `Integrations/Merchant.lua`; test in `tests/test_merchant.lua`; verify it passes
- [x] 4.3 In `plans/keepthat.yaml`, add the tooltip lines as diagnostic checks on kt.s2.1 to s2.4 and the merchant lines as required checks on kt.s4.2 and s4.3 (steps stay player, D7); add `covers:` for sections s2 and s4, citing only headings already in `openspec/specs/` (this change's new requirements exist there only after sync); verify `make plan` still validates `covers:` (if `ct.py` cannot find the specs folder, add `--specs openspec/specs` to the Makefile `plan` target)
- [x] 4.4 Record the new lines in `docs/contracts.md`; verify the wording matches the code

## 5. Section 3 (Loot toast)

- [x] 5.1 Add `[toast] shown <itemID>`, `[toast] skipped <itemID>: shown this session`, `[toast] sound <name> on <channel>` and `[toast] sound <name> unavailable; played the default` in `UI/Toast.lua`, and report `toast.seq` through `ns.CheckThat` when a toast shows; test both paths and the counter in `tests/test_toast.lua`; verify each fails when broken
- [x] 5.2 In the plan, add required `[toast] shown` to kt.s3.1 and required `[toast] sound` to kt.s3.3 (player steps); add `covers:` for s3; verify `make plan` and the replay
- [x] 5.3 Record the lines and the `toast.seq` fact in `docs/contracts.md`

## 6. Section 5 (Auctionator and Profession Journal)

- [x] 6.1 Add `[auctionator] export <profession> <category>: <n> items` and the `export.items` fact in `Auctionator.Export`, the `estimate.copper` fact next to the existing estimate line (only when the summary changes), and `[auctionator] estimate on` and `estimate off` in the setting's setter, each resetting the last summary; test in `tests/test_auctionator.lua` and `tests/test_options.lua`; verify each fails when broken
- [x] 6.2 Convert kt.s5.1 and kt.s5.3 to `auto: true` with required checks (D7); kt.s5.3's action turns the setting off and on and its checks are a `log-sequence` from `[auctionator] estimate on` to the estimate line, plus `estimate.copper` `op: type` `number`; keep kt.s5.2 and s5.4 as player steps; add `covers:`; verify `make plan` and the replay settle both auto steps
- [x] 6.3 Record the line and facts in `docs/contracts.md`

## 7. Sections 6 and 7 (Settings window and presentation)

- [x] 7.1 Add `[options] opened <page>` in `Options.Open` and `[options] launcher closed the game's Options and opened <page>` in the Materials launcher; test in `tests/test_options.lua`
- [x] 7.2 Add `[toast] move started`, `move done at <point> <x> <y>` and `move cancelled`, and the line for a move during combat that records what the code does today (design Open Questions); test in `tests/test_toast.lua`
- [x] 7.3 Add `[demo] started: toasts=<n> tooltip=<bool> tint=<bool>` and `[demo] ended`; test in `tests/test_slash.lua` or `tests/test_presentation.lua`
- [x] 7.4 Convert kt.s6.1 to auto; add required checks to kt.s6.2, s6.4 and s7.1, a diagnostic `errors` check to kt.s6.5, and `covers:` for s6 and s7; verify `make plan` and the replay
- [x] 7.5 Record the lines in `docs/contracts.md`

## 8. Section 8 (Cross-character stock)

- [x] 8.1 Add `[stock] bank counted: <n> slots` and `[stock] mailbox counted: <n> letters` in `Core/Stock.lua` where a reading replaces the container, with no character name; test in `tests/test_stock_recorder.lua`; verify it fails when broken
- [x] 8.2 Convert kt.s8.1 to auto with both lines as required `scope: attempt` checks; keep kt.s8.2 and s8.3 as player steps; add `covers:`; verify `make plan` and the replay
- [x] 8.3 Record the lines in `docs/contracts.md`

## 9. Sections 9 and 10 (Leveling numbers and recipe status)

- [x] 9.1 Add the `pj.listed` fact next to the existing `[professionjournal] on|off` line; test in `tests/test_professionjournal.lua`
- [x] 9.2 Convert kt.s9.1, kt.s9.2 and kt.s10.1 to auto: make their checks required, use `verify: [assertions]` only, and for s10.1 add a pattern for a probe line with `stale=0` and `mismatches=0`; add `covers:`; verify `make plan` and the replay
- [x] 9.3 Record the fact in `docs/contracts.md`

## 10. Integration checks

- [x] 10.1 Run `make test` and `make check`; both pass
- [x] 10.2 Run `make plan`, `ct.py offline plans/keepthat.yaml` and `luajit ../wow-checkthat/tests/replay_plan.lua build/keepthat.ct`; no warning and no problem
  - `make plan` and the replay (with `plans/keepthat.replay.lua`) pass with no warning; `ct.py offline` is blocked by 3.1.
- [x] 10.3 Where a step turns on a setting that `/kt set` or `/kt debug` accepts, put that command in the step's `commands:`; verify `make plan`
- [x] 10.4 Run `ct.py coverage plans/keepthat.yaml --addon-src KeepThat` and confirm that requirement, command and setting coverage rose from 0 of 106, 3 of 12 and 0 of 9; note the remaining gaps in the PR body
- [x] 10.5 Check `/kt log` in the fake client (`tests/test_log.lua`) for the `checkthat` row and the new lines; the PR body lists the in-game checks still needed as checkboxes (at most about 4)

## Workflow follow-up

- Set the version to 0.7.0 in both TOC files and the `kt.s1.1` `op: ge` value to 700 at sync or archive (design D10).
- Write the `## 0.7.0` `CHANGELOG.md` section at archive, and note that kt.s1.1 was renumbered to kt.s1.2.
- Archive before committing; then commit, push and open the PR only when asked.
