# Tasks

Each check is marked **unit** (`make test`) or **in-game**. The release checklist is the smoke check plus the 2 in-game checks (test plan section 13).

## 1. Unknown counts stay unknown (D1)

- [x] 1.1 `Model/Leveling.lua` `Need`: a source counts only with a counted step ahead, or with no step ahead and a counted passed step (0). Update the header comment. **Unit**, in `test_leveling`:
  - the review repro: one guide, 10 for 1-50, uncounted 75-100, skill 75 → `low` and `high` nil, the source still listed;
  - a second source needing 40 → count 40;
  - the existing passed-guide-as-0 range still passes;
  - verify the tests fail against the old code.
- [x] 1.2 Consumers with no count. **Unit**:
  - `test_options`: no "You have enough." when `high` is nil;
  - `test_auctionator`: the material is listed without a quantity;
  - `test_wording`: no count line.

## 2. Intermediate shares (D2)

- [x] 2.1 `Need` takes `via` from the source that sets `high`, each share rounded down. **Unit**, in `test_leveling`:
  - the shipped `Routes_Forever`, Engineering 106, Copper Bar (2840): shares sum to at most `high` (fails today: 59 + 13 > 62);
  - fractional shares from one source never sum above the rounded-up `high`;
  - verify the tests fail against the old code.

## 3. Collapsed Skills headers (D3, D4)

- [x] 3.1 `Core/Adapter.lua` `ProfessionSkills`: expand collapsed headers bottom-up, read, collapse each again found by name; `visibleOnly` skips the expand; only when both functions exist. **Unit**, in `test_adapter`, with a fake Skills list:
  - Tailoring under a collapsed Professions header is read;
  - afterwards exactly the same headers are collapsed;
  - two collapsed headers restore correctly;
  - without `ExpandSkillHeader`, only visible rows, as today;
  - a failed collapse leaves only that header open;
  - a failed count during the restore still collapses every header (fails with `count() or 0`);
  - the header each profession sits under is returned;
  - `visibleOnly` expands nothing and reports hidden rows;
  - verify the tests fail against the old code.
- [x] 3.2 `Core/Context.lua` `SkillsChanged` and `Core/Addon.lua`: `SKILL_LINES_CHANGED` reads only the visible ranks and invalidates when one changed; `CHAT_MSG_SKILL` and the learned-spell events invalidate. **Unit**, in `test_context`: no cache does nothing; an unchanged read does not refresh; a changed, new or dropped (nothing hidden) profession does; a profession out of view under its own collapsed header does not, one gone while only another header is collapsed does; with the real adapter, events fired at once or queued by expand and collapse die out after one expansion; a visible rank-up refreshes; a hidden one is picked up by the chat message (full read), and a chat message that changes no profession refreshes nothing. Verified failing with a full read in the event handler, with any-header hiding, and with a visible-only chat read. `test_smoke` still sees `SKILL_LINES_CHANGED` watched.

## 4. Profession Journal toggle (D5)

- [x] 4.1 `Integrations/ProfessionJournal.lua`: `PJ.Items` follows the toggle, except for stock (`PJ.Items(p, true)` from `Core/Stock.lua`, also before the integration starts, never on a client it does not run on or after it failed; the cache resets from load; `test_stock_recorder` and `test_professionjournal` fail without each); add `PJ.On`. **Unit**, in `test_professionjournal`: toggle off → no items; back on → items again, with no restart. Verify the test fails against the old code.
- [x] 4.2 `Options/Options.lua`: the tree cache rebuilds when `PJ.On()` changes. **Unit**, in `test_options`: a Journal-only material leaves the tree and `Options.Find` when the toggle is off, and returns when it is on. `test_stock_recorder` still passes.

## 5. Docs and release checks

- [x] 5.1 Docs:
  - `docs/contracts.md`: Era's Skills list returns only expanded rows; KeepThat expands and restores.
  - Debug log lines for the checks (CLAUDE.md "In-game testing"): `[skills]` with the ranks and collapsed headers when they change (`Context.LogSkills`), and `[professionjournal] on|off: N materials listed` on each toggle (`PJ.LogToggle`). **Unit**, in `test_context` and `test_professionjournal`.
  - `docs/test-plan.md` section "## 13. Leveling numbers", with 2 **in-game** checks, read from the saved variables:
    1. Classic Era: `/kt debug on`, collapse the Professions header, `/reload`, craft one skill-up, `/reload`; `global.log` shows `[skills]` with the real rank, then +1, each with `collapsed headers: Professions`.
    2. WoW Forever with Profession Journal: `/kt debug on`, turn it off and on, `/reload`; `global.log` shows `off: 0 materials listed`, then `on: N materials listed`.
  - `README.md` "Good to know", if a line covers these.
  - Verify with `make check` and `test_readme`.
- [x] 5.2 `make test` and `make check` pass.
- [ ] 5.3 In-game checks 13.1–13.2 reported by the player (the PR body carries them as checkboxes).

## Workflow follow-up

- At `/opsx:archive`: sync specs, bump both TOCs to 0.4.7, add the CHANGELOG line.
- The PR body lists checks 13.1–13.2 and the smoke check as checkboxes.
- Merge, tag and publish only when asked.
