# Design

## Context

- `Leveling.Need` (`Model/Leveling.lua`) sums each source's remaining segments. A source is "counted" as soon as any of its segments has a count, even a passed one. A source active only through uncounted (0, 0) segments therefore reports 0. The range then takes the largest count per intermediate (`via`) across all sources, independent of which source gives `high`.
- `A.ProfessionSkills` (`Core/Adapter.lua`) on Era walks `GetNumSkillLines` / `GetSkillLineInfo`. These return only rows under expanded headers. `Core/Addon.lua` calls `Context.Invalidate()` on `SKILL_LINES_CHANGED`, and listeners (tooltip, overlay) call `Context.Get()` again.
- `PJ.Extra` and `PJ.Professions` check the toggle (`I.Active("professionjournal")`); `PJ.Items` does not. `Context.extra` stays set after the toggle is turned off. The options tree rebuilds only when `Context.extra` changes identity.
- Shipped data: Forever has no guide whose material segments mix counted and uncounted; Era has 5 (First Aid cloth), and none of them reaches the 0 case. Only Profession Journal steps without a `total` can trigger review #4 today.

## Goals / Non-Goals

**Goals:** never claim a count of 0 for steps still ahead; read Era ranks whatever the Skills tab shows; make the Profession Journal toggle take effect without a reload; keep "Includes" shares within the count.

**Non-Goals:**
- **Partial counts.** A source with both counted and uncounted steps ahead keeps its counted part, as today. Its count is a lower bound; marking it so is out of scope.
- **Saving ranks across sessions.** Not needed once the headers are read expanded.
- **Other Profession Journal problems** (review #15, "working" after a failure). Planned for 0.4.9.

## Decisions

- **D1. A source counts only with a counted step ahead, or no step ahead.**
  - In `add`, set `e.counted` only for a segment with `high > 0` and `share > 0`. After the loop, a source with `not e.active` and any counted segment also counts (as 0), but only when some source has `e.counted`: that keeps the documented "steps passed in one guide" range, and a finished guide's 0 (a lower bound) never becomes the whole count next to a source with only uncounted steps ahead (Codex re-review).
  - A source active only through uncounted steps takes no part in `low`/`high`. When no source counts, `low` and `high` are nil. Every consumer already handles nil: `Wording.Count`, `toGetLine`, `levelingAlso`, the Auctionator list (adds the item without a quantity).
  - *Alternative:* any uncounted step ahead makes the whole source unknown. Rejected: it drops counts for 5 Era First Aid materials that are right today, for no player-visible gain.
- **D2. Shares from the top source, rounded down.**
  - `via` becomes the `via` table of the source that sets `high` (first in route order on a tie), each share rounded down. Within one source the shares sum to at most its unrounded high, so the rounded-down shares sum to at most the rounded-up `high`.
  - *Alternative:* keep the per-intermediate maximum and cap the sum. Rejected: harder to explain, and the numbers would come from different guides.
- **D3. Expand, read, restore by name (Era).**
  - Only on the `GetSkillLineInfo` path, and only when `ExpandSkillHeader` and `CollapseSkillHeader` exist. Walk the rows from the bottom up; expand each header with `isExpanded` false and remember its name. Read every row. Then collapse each remembered header, finding its current index by name each time, so one failed collapse leaves only that header open (Codex re-review: by index, a failure shifted the others).
  - Expanding bottom-up is Armory-Classic's `SetExpandableListValues` order. Era has no headers nested under headers; a nested collapsed header would not be read (noted, not handled).
  - `A.ProfessionSkills(visibleOnly)` skips the expand and returns, second, whether a collapsed header hid rows.
- **D4. Skill events cannot loop.**
  - The expand and collapse in D3 fire `SKILL_LINES_CHANGED`, during the call or on a later frame. A first version ignored that event for 1 second after a read; Codex showed it lost a real rank-up inside that second and could loop again with later events.
  - Now `SKILL_LINES_CHANGED` calls `Context.SkillsChanged()`, which reads with `visibleOnly` (never changes the Skills list, so it fires nothing) and invalidates when a visible rank differs from the cached one, or a cached profession is gone and its own header (remembered from the last full read) is not collapsed now. An unrelated collapsed header no longer hides a removal (Codex second review). With no cached context it does nothing: nothing was read since the last invalidation (this also stops recursion during a read in progress).
  - A rank-up under a collapsed header is invisible to that check. `CHAT_MSG_SKILL` ("Your skill in Tailoring has increased to 151.") calls `SkillsChanged(true)`: a full read, invalidating only when a rank changed, so weapon skill-ups refresh nothing. `LEARNED_SPELL_IN_TAB` and `LEARNED_SPELL_IN_SKILL_LINE` invalidate directly. Expanding headers never sends a chat message, so these cannot loop.
  - `SkillsChanged` keeps the context it started from: the full read can fire `SKILL_LINES_CHANGED` at once, and if that nested call already refreshed, it stops (Codex third review: it raised a Lua error).
  - The restore scan falls back to the expanded row count when `GetNumSkillLines` fails, so a failed count cannot leave headers open.
- **D5. The Profession Journal toggle.**
  - `PJ.Items` returns an empty list when `on()` is false, as `Extra` and `Professions` do. This covers the Materials tree, `/kt find` (`Options.Find`) and the Auctionator list.
  - Stock (`R.Tracked`) calls `PJ.Items(p, true)`, which ignores the toggle, and no longer needs the integration to have started this session (`ctx.extra`): stock records materials whatever the settings mark, and a bank read while it is off, or in a session that started with it off, must keep them, or the total is short once it is back on (Codex reviews). Without Profession Journal installed, `PJ.Items` reads nothing. It still respects the gate: nothing on a client the integration does not run on, or after it failed this session. The read cache resets on every context change from load (not only once started), and caches nothing while Profession Journal is not loaded, so one that loads later is seen. `R.Tracked` also rebuilds when `PJ.StockReadable()` changes (a late load or a failure), with no context change needed (Codex fourth review).
  - The options tree cache keys on `ns.Context.extra and PJ.On()` (a new `PJ.On` that exposes `on()`), so it rebuilds when the toggle changes either way.
  - Settings changes already call `Context.Invalidate()`, which rebuilds `R.Tracked` and the classifier context.

## Risks / Trade-offs

- **[Expanding headers while the player has the Skills tab open]** → The frame updates on the next draw, after the restore, so nothing visible changes. In-game check 1 confirms.
- **[The game fires SKILL_LINES_CHANGED for each expand and collapse]** → D4 answers with a read that changes nothing. `test_context` fires them at once and queued (any delay) and checks they die out after one expansion.
- **[A client sends no CHAT_MSG_SKILL for a rank-up under a collapsed header]** → That rank is stale until the next refresh (a setting change, a learned recipe, or a reload). In-game check 13.1 only covers the read at login; a rank-up with the header collapsed is worth a look during it.
- **[A material that used to show "You have enough." now shows no count]** → Correct: the guide gives none. Only Profession Journal steps without totals are affected.
