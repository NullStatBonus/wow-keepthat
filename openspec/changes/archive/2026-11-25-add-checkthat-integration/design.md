# Design

## Context

See proposal.md for why. Facts from the code and the CheckThat docs that shape the approach:

- `Integrations/Gate.lua` registers integrations. `allowed()` starts one on WoW Forever only unless its spec sets `anyClient = true`, and `anyClient` integrations have no toggle. `I.Start()` runs at KeepThat's start, on every later `ADDON_LOADED` and at `PLAYER_LOGIN`. `I.Fail(key, why)` turns one off for the session and records `[key] FAILED: why`. `I.Keys()` feeds the "Integrations:" block of `/kt log`.
- The Integrations page lists a fixed `Options.INTEGRATIONS` table, so an unlisted key gets no row.
- `ns.Log.Record(area, msg)` stores `[area] msg` in `KeepThatDB.global.log` (300 lines, no time) only while `/kt debug on`. `ns.Log.Failure` is always kept for the report.
- CheckThat (features.md, debug-logging.md): `CheckThat.Report(addon, key, value)` returns false and records nothing when no run is open. It never raises an error by design. It keeps 300 lines and accepts 30 facts a second. Keys are 1 to 48 of `[%w_.-]`, values are text up to 120 characters, finite numbers or booleans. `CheckThat.Entry(addon, name, fn)` must be called at `PLAYER_LOGIN` because CheckThat loads after the addons it lists. An entry runs when its step opens and its result is the fact `[KeepThat] entry.<name>=<returns joined by commas>`. A fact reported before a step opened does not count for that step. `CheckThat.API_VERSION` is 2 and later versions only add.
- `ct.py validate` warns unless the first step's title, expect, action text or an assertion key contains "version". An `auto` step verifies by assertions only, needs one required check, cannot use `exactly` or `max`, and needs a `timeout` for an absence check.
- `ct.py coverage plans/keepthat.yaml --addon-src KeepThat` today: commands 3 of 12, settings 0 of 9, requirements 0 of 106.

## Goals / Non-Goals

**Goals:**
- One contained file for every CheckThat call, safe with CheckThat missing, old or idle.
- A first plan step that checks the version with no player input.
- Evidence (line, fact or entry) for every plan step that does not depend on drawing, sound, position or feel, and `auto: true` on those steps.

**Non-Goals:**
- No new setting, slash command or Integrations page row. No change players can see.
- No change to CheckThat. If KeepThat needs something CheckThat lacks, open an issue there (AGENTS.md).
- No automatic proof of drawing: tint color, tooltip layout, toast position, sound, click-through.
- No multi-character plan (`plans/keepthat.<role>.yaml`).

## Decisions

### D1. One integration file, registered with the Gate as `anyClient`

`Integrations/CheckThat.lua` calls `ns.Integrations.Register("checkthat", { anyClient = true, detect, start })`. `detect` returns true when the global `CheckThat` table exists. With `anyClient` it runs on Classic Era too and has no toggle, so no `Defaults` key, no README setting and no Integrations page row. The "Integrations:" block of `/kt log` lists it through `I.Keys()`. This needs the MODIFIED "Integrations on WoW Forever only in this version" requirement in the settings delta.

The file exposes a KeepThat-side wrapper, `ns.CheckThat.Report(key, value)`. Feature modules load earlier than `Integrations/`, so they look it up at call time (`if ns.CheckThat then ns.CheckThat.Report(...) end`), as they do with `ns.Log`. They never cache it at file scope. The wrapper does nothing unless `ns.Integrations.Active("checkthat")` and `CheckThat.Report` exist, and calls it in `pcall`.

- *Alternative: a toggle on the Integrations page.* Rejected. The integration has no effect without an open run, and memory and AGENTS.md ask for lean menus.
- *Alternative: call `CheckThat.Report` directly in each module.* Rejected by AGENTS.md ("One integration file").

### D2. A false return is not a failure

`CheckThat.Report` returns false whenever no run is open, a key is refused or the rate limit drops a fact. The wrapper ignores the return value. Only an error raised inside the `pcall` calls `ns.Integrations.Fail("checkthat", err)`, after which the wrapper and the Gate's guard do nothing for the session. Otherwise the integration would fail in every session without a run.

### D3. The version comes from an entry, not a command or a login fact

A `version` entry returns `major*10000 + minor*100 + patch` parsed from `ns.version` (0.7.0 is 700, the same encoding as CheckThat's own `version` fact). When `ns.version` is "unknown" or does not parse, it returns nothing. The plan's new first step is:

```yaml
- id: kt.s1.1
  title: KeepThat version
  auto: true
  action: { kind: manual, text: CheckThat reads the KeepThat version. }
  expect: The KeepThat version is 0.7.0 or newer. If the step fails, copy KeepThat 0.7.0 into the game again.
  verify: [assertions]
  call: { addon: KeepThat, entry: version }
  timeout: 30
  assertions:
  - { kind: fact, source: facts, addon: KeepThat, key: entry.version, op: ge, value: 700 }
```

The value tracks the version set at sync or archive. The old "No Lua errors" step becomes `kt.s1.2`. No code or doc cites test plan check 1.1, so `tests/test_plan.lua` stays green.

- *Alternative: `/kt version` plus a `copy-slash` action, as CheckThat does.* Rejected. It adds a player command (README, `tests/test_readme.lua`, listing) and a player action to a check that needs none.
- *Alternative: report `version` at `PLAYER_LOGIN`.* Rejected. A fact reported before the step opens does not count.

### D4. Entries register at `PLAYER_LOGIN` from inside `start`

The Gate first runs `start` at CheckThat's own `ADDON_LOADED`, which comes before `PLAYER_LOGIN`. `start` therefore registers the entries at `PLAYER_LOGIN`. AceEvent (CallbackHandler) keeps one handler per event per object, and the Gate already listens for `PLAYER_LOGIN` on the addon object (`Gate.lua`), so a second `ns.Listen(addon, "PLAYER_LOGIN", ...)` would replace the Gate's login start. The integration listens on a module of its own, `addon:NewModule("CheckThat", "AceEvent-3.0")`, as `Core/Stock.lua` does, through `ns.Listen`, so no game call leaves the adapters. If `start` runs after login, which happens only when CheckThat is loaded late, it registers at once. A new `ns.Adapter.LoggedIn()` (guarded `IsLoggedIn`, nil when missing) tells it which case applies. Each registration is guarded by `if CheckThat and CheckThat.Entry` and runs in `pcall`. Each entry body runs in `pcall` as well. On an error it records `ns.Log.Failure("checkthat", "entry <name>: <message>")` (a `FAILED:` line, kept in the report) and returns the text `error: <message>` cut to 100 characters. CheckThat would report a raised error as `threw:`, but a contained error keeps the Gate rule that KeepThat never raises. An entry error does not turn the integration off: it concerns one call made on a tester's request.

Entries (names are the CheckThat contract and go in `docs/contracts.md`):

| Entry | Args | Returns | Source of truth |
| --- | --- | --- | --- |
| `version` | none | number, or nothing | `ns.version` |
| `classify` | itemID | categories and professions, such as `endgame:Blacksmithing` (several joined with `;`), or nothing for an unmarked item | `Model/Classify` `Classify.Item` with the current context |
| `needed` | itemID, profession | count still needed, or nothing when unknown | `Model/Leveling` `Leveling.Need` |
| `exportCount` | profession, category | item count, list name | `Auctionator.Materials` and `ListName`, added to the `ns.AuctionatorExport` table (never `Export`, which writes) |
| `setting` | public key | the value `/kt get` prints | `ns.Presentation.Value(key)`, the allowlisted registry `/kt get` uses |
| `integration` | key | `working` or the Gate reason | `ns.Integrations.Status` |
| `stockCounted` | none | true, false, or nothing | `ns.StockRecorder.State().missing` for this character only, with no names |

Every result is scalar, at most 120 characters, and holds no character name.

### D5. Facts

| Key | Value | Decision point | Plan use |
| --- | --- | --- | --- |
| `export.items` | number | `Auctionator.Export` after the list is written | kt.s5.1 `op: ge 1` |
| `estimate.copper` | number | `Auctionator.EstimateLines`, only when the summary changes (the existing guard) | kt.s5.3 `op: type, value: number` |
| `pj.listed` | number | `ProfessionJournal` toggle, next to its existing on/off line | kt.s9.2 `op: gt 0` |
| `toast.seq` | number, +1 per toast this session | `Toast.Handle` when a toast is shown | kt.s3.1 count of new toasts |

Facts only add to a line that already exists. A plan checks a fact when it needs a numeric operator or a count. The debug log has no time, so the log cannot show where a step began for `exactly`, `max` or `absent`. Those checks use a fact with a counter or the quiet `errors` source, or the step stays a player step.

### D6. Debug lines the plan checks

New or stabilized lines. Wording is fixed here and goes in `docs/contracts.md`. A reword is a plan change.

| Area | Line | Where | Step |
| --- | --- | --- | --- |
| `tooltip` | `line added <itemID> via <path>`, once per item and path per session | `UI/Tooltip.lua` where the line is added | kt.s2.1, s2.3, s2.4 (diagnostic) |
| `tooltip` | `line skipped <itemID>: already on this tooltip`, once per item per session | the duplicate guard | kt.s2.2 (diagnostic) |
| `toast` | `shown <itemID>` and `skipped <itemID>: shown this session` | `Toast.Handle` | kt.s3.1 |
| `toast` | `sound <name> on <channel>` and `sound <name> unavailable; played the default` | `playSound` | kt.s3.1, s3.3 |
| `toast` | `move started`, `move done at <point> <x> <y>`, `move cancelled` | `Toast.BeginMove`, `DoneMove`, `CancelMove` | kt.s6.4, s6.5 |
| `merchant` | `tinted <n> of <m> on page <p>` and `tinted <n> of <m> on buyback`, once per page shown | `Integrations/Merchant.lua` after a page paints | kt.s4.2, s4.3 |
| `auctionator` | `export <profession> <category>: <n> items` | `Auctionator.Export` | kt.s5.1 |
| `auctionator` | `estimate on` and `estimate off`; each resets the last summary, so the next page draw logs the estimate again | the "Estimate leveling cost" setter on the Integrations page | kt.s5.3 |
| `options` | `opened <page>` | `Options.Open` | kt.s6.1 |
| `options` | `launcher closed the game's Options and opened <page>` | `Options.MaterialsLauncher` | kt.s6.2 |
| `demo` | `started: toasts=<n> tooltip=<bool> tint=<bool>` and `ended` | the `demo` dependency in `Core/Slash.lua` and the tint reset | kt.s7.1 |
| `stock` | `bank counted: <n> slots` and `mailbox counted: <n> letters` | `Core/Stock.lua` where a reading replaces the container | kt.s8.1 |
| `checkthat` | `started` (the Gate), `entries registered: <n>` | `Integrations/CheckThat.lua` | kt.s1.1 (diagnostic) |

Existing lines that the plan already matches stay as they are: `[blizzard] hooked`, `[merchant] hooked`, `[<bag addon>] started`, `[auctionator] estimate ...`, `[professionjournal] on|off: N materials listed`, `[skills] ... collapsed headers`, `[recipes] <profession> complete=...`, `[recipes] recipe probe: ...` and the two `[stock] ... changed as it closed` lines.

A line that can repeat at high rate, such as tooltip and merchant paints, is written once per key per session or once per changed value. The 300-line log must not fill with repaints.

### D7. Step conversion

| Step | Result | Evidence |
| --- | --- | --- |
| kt.s1.1 (new) | auto | `entry.version` `op: ge` |
| kt.s1.2 (was s1.1) | player | Errors from KeepThat's load come before CheckThat's handler exists. A diagnostic `errors` check is added. |
| kt.s2.1 to s2.4 | player | One line and its color are drawing. Diagnostic tooltip lines. |
| kt.s3.1 | player, with a required `[toast] shown` check | Sound and fade |
| kt.s3.2 | player | Click-through |
| kt.s3.3 | player, with a required `[toast] sound` check | Hearing the sound |
| kt.s4.1 to s4.4 | player | Tint. Merchant lines become required checks on s4.2 and s4.3. |
| kt.s5.1 | auto | `[auctionator] export tailoring leveling` and `export.items` `ge 1` |
| kt.s5.2, s5.4 | player | Tooltip content depends on the character's route |
| kt.s5.3 | auto | `[auctionator] estimate on`, then the `[auctionator] estimate tailoring:` pattern and `estimate.copper` (`log-sequence`, `scope: attempt`). The page draws the same value it logs. The action turns the setting off and on, so a setting left on from an earlier run still writes new lines. |
| kt.s6.1 | auto | `[options] opened home` |
| kt.s6.2 | player, with a required launcher check | The game's Options page layout is drawing |
| kt.s6.3, s6.6, s6.7, s7.2 | player | Clipboard, AddOns list, report copy, layout |
| kt.s6.4 | player, with a required `move done` check | Position |
| kt.s6.5 | player, with a diagnostic `errors` check | Feel |
| kt.s7.1 | player, with required `[demo]` checks | Drawing |
| kt.s8.1 | auto | `[stock] bank counted` and `[stock] mailbox counted`, `scope: attempt` |
| kt.s8.2, s8.3 | player | The race line appears only when the race happens |
| kt.s9.1, s9.2 | auto | Existing pattern and log-sequence checks become required |
| kt.s10.1 | auto | `[recipes] tailoring complete=true` and a probe line with `stale=0` and `mismatches=0` |

The plan gains `logs.facts` (`CheckThatDB`, `global.facts`, strings, cap 300) and `logs.errors` (`global.errors`, strings, quiet, cap 100). Each section and converted step gains `covers:` with the requirement headings it proves. `validate` accepts only headings already in `openspec/specs/`, so `covers:` cites existing requirements. This change's own new requirements can be cited only after sync. Where a step turns on a setting that `/kt set` or `/kt debug` accepts, the command goes in its `commands:`, which also raises command and setting coverage.

`kt.s8.1` cannot call `stockCounted` itself, because an entry runs when the step opens, before the player opens the bank. The entry is for the offline block and for a later step.

### D8. Offline block

`offline:` loads `wow-keepthat/KeepThat/KeepThat_Vanilla.toc` in CheckThat's fake client and calls the entries (`version`, `classify` for Arcanite Bar, `setting`, `integration`). The runner fires only the events a step names. The block therefore starts with `{event: {name: ADDON_LOADED, args: [KeepThat]}}` and `{event: {name: PLAYER_LOGIN}}`. The first task of phase 2 confirms that AceAddon and the Gate start in the fake client and that `ct.py offline` passes.

### D9. Phases and how this change may split

The tasks run in the requested order: integration and version, then entries, lines and facts, then step conversion by plan section. AGENTS.md requires a plan change to land in the same change as the line, fact or entry it matches. A split must therefore be vertical:

- **Phase 1** (tasks 1 and 2: the integration file, the wrapper, the version entry, `kt.s1.1`) can ship alone as its own change and release. It clears the validate warning.
- **After phase 1**, each later change takes one or more plan sections with their lines, facts, entries, tests, contracts and step conversion together. Phase 2 (entries and the offline block) can go with the first such section.
- Do not split "all log lines" from "all conversions". A line with no plan check, or a check with no line, breaks the rule.

If the work splits, phase 1 keeps this change name and the specs stay as written. Each later change names the scenarios it delivers.

### D10. Version

This adds a capability (the `checkthat-integration` spec), so the pre-1.0 rule gives a minor bump: 0.6.1 to **0.7.0**. If phases ship as separate releases, phase 1 is 0.7.0 and each later section change is a patch (0.7.1, ...), because it changes logging and plan content of existing behavior. If the user treats the whole change as tooling with no player-visible effect, 0.6.2 fits the patch rule. This design assumes 0.7.0.

## Risks / Trade-offs

- [The fake client may not run AceAddon's start-up] → Task 3.1 checks this first. If it fails, the offline block covers only entries that need no saved settings, and an issue goes to CheckThat.
- [High-rate lines fill the 300-line log] → once-per-key guards (D6), with unit tests that call the paint path many times.
- [Renumbering kt.s1.1 breaks run history] → `ct.py trend` loses one step's history once. Recorded in the changelog at archive.
- [CheckThat changes its API] → only `Report` and `Entry` are used, each existence-checked. `API_VERSION` 2 only adds.
- [An auto step passes on a line from an earlier step] → required checks on converted steps use `scope: attempt` unless a step relies on an earlier line on purpose.
- [Entries run code at another addon's request] → entries are side-effect free (spec), and CheckThat calls them only during a run or with its off-by-default login check.

## Open Questions

- kt.s6.5 (Move in combat): the line the code writes depends on how `Toast.BeginMove` treats combat today (refuse or allow). The task records whichever happens and does not change the behavior.
- kt.s5.2: a `sources` entry could make it automatic if the plan names a fixed material. Leave it for a later change.

## Implementation notes (apply, 2026-11-25)

- **Task 3.1: AceAddon does not start in CheckThat's fake client (0.20.1).** `tools/entry_runner.lua` `loadToc` loads only the `.lua` lines of a TOC and does not follow `embeds.xml`, so `Core/Addon.lua` stops at `LibStub` and no KeepThat file after it runs. The D8 fallback ("entries that need no saved settings") does not help, because nothing loads. With a local copy whose TOC lists the files `embeds.xml` names, AceAddon, AceDB and the Gate start and all seven offline steps pass (`version`, `classify` for Arcanite Bar and an unmarked item, `setting tooltip`, `integration checkthat`). The block stays in the plan as written. Second gap: `ct.py offline` validates without the specs folder, so a plan with `covers:` is refused ("covers needs the addon's openspec/specs folder"). Both go to a CheckThat issue (drafted, not filed: filing is for the maintainer).
- **The fake client has no TOC metadata**, so `version` returns nothing offline. The offline step checks that (the "Version unknown" scenario); the in-game step kt.s1.1 checks `ge 700`.
- **`tests/replay_plan.lua` writes only CheckThat's own debug log** and reads `contains`/`equals` checks, so KeepThat's steps were never reached (25 problems before this change). `plans/keepthat.replay.lua` is a hooks file that writes the KeepThat lines and facts each step expects; with it the replay settles every step and a reworded line shows as a problem.
- **Stock lines (D6) say `materials`, not `slots` and `letters`.** `ReadContainer` and `ReadInbox` return only tracked item counts, so the count is the number of tracked materials in the reading: `[stock] bank counted: <n> materials`, `[stock] mailbox counted: <n> materials`.
- **Open question kt.s6.5:** `Toast.BeginMove` does not check combat (it refuses only when the toast is locked), so a move in combat writes the normal `move started` line and nothing else.
- **`[demo] ended`** is written when the tint sample hides, so only when the tint showed.
