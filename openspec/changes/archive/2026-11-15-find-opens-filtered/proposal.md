## Why

`/kt find arcanite bar` printed paths in chat and opened nothing, because Arcanite Bar is listed under two professions and several paths only produced a chat list. Players expect the command to show the matches in the KeepThat window.

## What Changes

- When several paths match, `/kt find <name>` opens the KeepThat window on Materials with the search set to the query, and expands only the professions that have a match. No chat list.
- One match still opens that material's page. No match, a missing name, and a match hidden by the Home checkboxes still answer in chat; when every match is hidden, chat says which Home checkbox shows them.
- Corrects the 0.2.1 scenario that said `/kt find Arcanite Bar` opens one profession.

## Capabilities

### New Capabilities

### Modified Capabilities
- `settings`: Material search (`/kt find` with several matches) and Materials professions start collapsed (find scenario).

## Impact

- `KeepThat/Core/Slash.lua` (find branch), `KeepThat/Options/Options.lua` (`Options.OpenSearch`), `tests/test_slash.lua`, `tests/test_options.lua`, `README.md` command table, `docs/test-plan.md`.
- Ships in the unreleased 0.2.1 (same PR); CHANGELOG line updated.
