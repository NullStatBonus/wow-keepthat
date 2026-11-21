# KeepThat

## Documentation

When player-visible behavior, a setting, or a command changes, update the supporting docs in the same change.

- Cover affected features, settings, commands, and “Good to know” limits in `README.md`.
- Update the CurseForge/Wago text in `docs/listing.md`. Update its summary when the headline behavior changes.
- Update `docs/test-plan.md` with the relevant manual checks. Keep section numbers unique and in order.
- Document every new setting in the README and include its value in the debug report.
- Check the report with `/kt log`.
- Update `docs/data.md` when a data format or generator changes.
- Record what a client or another addon provides in `docs/contracts.md` whenever a probe or source review measures it.
- `tests/test_readme.lua` checks the README command list.

## Testing

- Cover each new behavior with an automated test. Temporarily break the behavior, verify the test fails for the expected reason, then restore the behavior and verify it passes.
- Run the focused test during implementation. Use `make test` for the full suite and `make check` for packaging and version checks.
- Keep manual checks short and few. Give each check one player action, then a `Check:` line that states the expected result in words a player understands. Put the log line that proves it on a separate `Log:` line for the reviewer. Never ask the player to read or interpret a log line. Log a distinct line for each behavior the check verifies.
- Give only essential setup before the action, but name everything the check depends on: a profession, an installed addon, and turning on debug logging followed by `/reload`. Avoid old versions, disabled addons, and staged characters or items.
- Verify the result from debug logs or saved variables wherever possible. Add missing evidence in the same change.
- Keep raw saved variables and debug output out of Git. Anonymize any fixture derived from them.
- Each module's tests live in `tests/test_<module>.lua`, or in the file of the feature the module serves. The area files are: `test_core` (`Core/Init`, `Core/Addon`, `Core/Defaults`), `test_integrations` (`Integrations/Gate`, `Blizzard`, `Baganator`, `Bagnon`, `EllesmereUI`), `test_merchant` (`Integrations/Merchant`, `Core/Adapter_Merchant`), `test_stock_recorder` (`Core/Stock`), and the feature file for each other `Core/Adapter_<Area>` (`test_tooltip`, `test_toast`, `test_adapter_stock`; `Adapter_Bags` with the bag integrations, `Adapter_Sound` in `test_adapter`). Generated `Data/` files are one module: `test_data` checks the catalogs, and `test_classify`, `test_leveling` and `test_auctionator` run on the shipped routes. A new module gets its own file unless it joins one of these areas.
- Reserve in-game checks for what unit tests cannot prove. Read the copied `/kt log` report or saved variables yourself. Ask for an on-screen observation only when neither captures the result.

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
