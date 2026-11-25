# KeepThat

## Documentation

When player-visible behavior, a setting, or a command changes, update the supporting docs in the same change.

- Cover affected features, settings, commands, and “Good to know” limits in `README.md`.
- Update the CurseForge/Wago text in `docs/listing.md`. Update its summary when the headline behavior changes.
- Update the in-game test plan, `plans/keepthat.yaml`, as the CheckThat section says. `docs/test-plan.md` only points to it. `tests/test_plan.lua` checks its step ids and every "test plan N.M" reference to them.
- Document every new setting in the README and include its value in the debug report.
- Check the report with `/kt log`.
- Update `docs/data.md` when a data format or generator changes.
- Record what a client or another addon provides in `docs/contracts.md` whenever a probe or source review measures it.
- `tests/test_readme.lua` checks the README command list.

## Testing

- Cover each new behavior with an automated test. Temporarily break the behavior, verify the test fails for the expected reason, then restore the behavior and verify it passes.
- Run the focused test during implementation. Use `make test` for the full suite and `make check` for packaging and version checks.
- Keep manual checks short and few. Give each player step one action (`action.text`), then an `expect` that states the result in words a player understands. Put the proof for the reviewer in `reviewer` and `assertions`. Never ask the player to read or interpret a log line.
- Give only essential setup before the action, but name everything the check depends on: a profession, an installed addon, and turning on debug logging followed by `/reload`. Avoid old versions, disabled addons, and staged characters or items.
- Verify the result from debug logs or saved variables wherever possible. Add missing evidence in the same change.
- Keep raw saved variables and debug output out of Git. Anonymize any fixture derived from them.
- Each module's tests live in `tests/test_<module>.lua`, or in the file of the feature the module serves. The area files are: `test_core` (`Core/Init`, `Core/Addon`, `Core/Defaults`), `test_integrations` (`Integrations/Gate`, `Blizzard`, `Baganator`, `Bagnon`, `EllesmereUI`), `test_merchant` (`Integrations/Merchant`, `Core/Adapter_Merchant`), `test_stock_recorder` (`Core/Stock`), and the feature file for each other `Core/Adapter_<Area>` (`test_tooltip`, `test_toast`, `test_adapter_stock`; `Adapter_Bags` with the bag integrations, `Adapter_Sound` in `test_adapter`). Generated `Data/` files are one module: `test_data` checks the catalogs, and `test_classify`, `test_leveling` and `test_auctionator` run on the shipped routes. A new module gets its own file unless it joins one of these areas.
- Reserve in-game checks for what unit tests cannot prove. Read the copied `/kt log` report or saved variables yourself. Ask for an on-screen observation only when neither captures the result.

## CheckThat

CheckThat (`../wow-checkthat`) runs the in-game test plan. Its docs are the contract: `docs/debug-logging.md`, `docs/features.md` ("Facts from other addons", "Entry points", "Automatic steps", "Unit-test checks") and `docs/authoring-plans.md`. Install its skills once with `make install-skill` in that checkout; use `/ct-test-plan` to write plans and `/ct-verify` to read runs.

- **The plan lives here.** `plans/keepthat.yaml` (and `plans/keepthat.<role>.yaml` for checks that need several characters) is the plan of record. Change it in the same change as the log line, fact or entry it matches. Its first step checks the version under test with `op: ge`. Step `kt.s<N>.<M>` is "test plan check N.M"; keep section and step numbers unique and in order.
- **Prefer automatic steps.** A check proven by a log line, a fact or an entry is an `auto: true` step. Keep a player step only for what the log cannot show: drawing, sound, position, feel. Each player step follows the Testing rules above.
- **Log lines.** Every behavior a plan checks writes one line at its decision point with the values that prove it. Log refusals and skips too, mark failures `FAILED:`, log toggles in both directions, and keep wording stable. A reworded line is a plan change. Never log character names or chat text.
- **Facts.** Report a value with `CheckThat.Report("KeepThat", key, value)` once, where the code decides it, never in a loop or an update handler. Report numbers as numbers. Add a changing value (a counter) where a plan checks "exactly n" or "absent".
- **Entries.** Expose pure functions a plan should call (classification, needed counts, export contents, settings state) with `CheckThat.Entry`, registered at `PLAYER_LOGIN`, never at file scope. Cover them in the plan's `offline:` block.
- **One integration file.** All CheckThat calls live in `Integrations/CheckThat.lua`, each guarded (`if CheckThat and CheckThat.Report then ... end`), so KeepThat works when CheckThat is missing or old. Do not add CheckThat to `OptionalDeps`: CheckThat lists KeepThat, so KeepThat loads first.
- **Before a tester runs a plan:** `make plan` (`ct.py validate`, then `ct.py compile` to `build/keepthat.ct`), `ct.py offline`, `luajit ../wow-checkthat/tests/replay_plan.lua build/<plan>.ct`, and `ct.py coverage <plan> --addon-src KeepThat` to list what is still uncovered. Run `ct.py` from this repository's root as `../wow-checkthat/.venv/bin/python ../wow-checkthat/tools/ct.py`, so `plans/keepthat.yaml` is this plan and not CheckThat's sample. Read runs back with `ct.py collect --plan <plan>` before asking for more in-game steps.
- **Contracts.** A new log format, saved variable or fact key goes in `docs/contracts.md` here, and in `LOGS` in CheckThat's `tools/ct.py` when the format or path changes.
- If KeepThat needs something CheckThat lacks, open an issue in the CheckThat repository instead of working around it.

## Conventions

- **Game calls live in `Core/Adapter*.lua` only** (`Core/Adapter.lua` plus one `Core/Adapter_<Area>.lua` per feature area, each adding functions to `ns.Adapter`). Every function the game provides is read there, guarded and in `pcall`, returning nil when missing; feature modules never call `C_*`, container, unit, item or tooltip functions directly. Unknown data is nil, never 0 or false.
- **Logic is plain Lua.** `Model/` and `Data/` have no game globals, so they run under `luajit tests/run.lua`. UI and integration modules take the adapter as input so tests can pass a fake.
- **Integrations are optional and contained.** Each one lives in its own file under `Integrations/`, detects its addon, runs inside `pcall`, and on any failure turns itself off for the session and records why in the debug report. A missing or changed addon never raises a Lua error.
- **Every player-facing sentence is `L["The whole English sentence"]`.** No concatenation, no variable keys. `tests/test_locale.lua` enforces this. See `docs/localization.md`.
- **New files go in both TOC files in the same order** (`make check` fails otherwise). The `Locales` files load first; `Libs/` is loaded by `embeds.xml`.
- **Generated data is never edited by hand.** Files in `Data/` come from `tools/`; change the inputs or the generator and regenerate. Credit every data source in `THIRD_PARTY.md`.
- **Chat text** never contains a raw `|`; double it.
- Choose game API code paths by checking whether the function exists, never by the client's name.
- Persistent visuals default to a pure black background, with a user-selectable color. Draw no fill, border, or texture at zero opacity. Keep text and icons dimmable and avoid bright fixed-position fills.
- For each new UI control or screen, check Blizzard UI source and popular addons for an established pattern. Use a standard control when available. If a custom control is necessary, keep the standard fallback where the custom control is unavailable.

## OpenSpec, Git, and releases

- Follow the matching workflow under `.claude/skills/`. The archive procedure is in `.claude/skills/openspec-archive-change/SKILL.md` (`/opsx:archive` in Claude Code).
- Bump the version once per OpenSpec change when its specs are applied to `openspec/specs/` during sync or archive. If `/opsx:sync` already set the version, keep it at archive.
- Set the same `## Version:` in `KeepThat/KeepThat_Vanilla.toc` and `KeepThat/KeepThat_Camelot.toc`. These are the only files that hard-code the addon version.
- Before 1.0, bump minor for a new capability or player-visible feature and patch for a fix or modification to existing behavior. From 1.0 onward, follow semantic versioning. Breaking saved settings or data requires a major bump from 1.0 onward.
- Archive before committing, pushing, or opening a PR for the change. Keep the code, synced specs, archive, version bump, and matching `## X.Y.Z` changelog section in the same commit. Name the new version in the commit message. A change still active in `openspec/changes/` is ineligible for commit.
- Write `CHANGELOG.md` at archive. Order entries by `New:`, `Changed:`, `Fixed:`, and `Removed:`. Bold the main item. For each fix, say what players saw before. Write one short line per entry in ASD-STE100 Simplified Technical English. Use active voice, simple tenses, common words, one fact per sentence, and at most 20 words per sentence. Describe what players see. Put settings-page, debug-report, and implementation details in the README.
- To publish, tag the archive commit `vX.Y.Z`, matching the TOC version, and push the tag as described in `docs/publishing.md`.
