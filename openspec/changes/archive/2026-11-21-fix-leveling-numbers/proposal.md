# Proposal

## Why

The 2026-11-20 bug review found four ways the leveling numbers can be wrong: a false "You have enough", whole-route counts for a profession the player knows, Profession Journal materials that stay after it is turned off, and intermediate shares that add up to more than the count. This is the third small patch from that review (release 0.4.7). Two fixes need an in-game check; the other two are proven by unit tests.

## What Changes

- **Unknown counts stay unknown (review #4).** A source whose only remaining steps for a material give no count used to report a count of 0. The material page then said "You have enough." and the Auctionator list left it out.
  - Now that source takes no part in the count. When no source has a count, the page says the guides give no count, and the Auctionator list includes the material without a quantity.
  - A source whose steps are all passed still counts as 0 next to a source that still has a count ahead (a lower bound), as today; on its own it no longer makes the count 0.
  - Shipped guide data never hits this case; Profession Journal's route can (steps without totals). **Unit** only.
- **Collapsed Skills headers on Classic Era (review #5).** Era lists profession ranks only for the rows the Skills tab shows. A collapsed "Professions" or "Secondary Skills" header hid the rank, so KeepThat counted the whole route from skill 1.
  - KeepThat now opens the collapsed headers, reads the ranks and closes them again, as Armory does. The Skills tab looks the same afterwards.
  - Opening and closing headers makes the game report a skill change. That report now checks only the ranks already visible, which never opens a header, so it cannot loop. A rank-up under a collapsed header is picked up from the skill chat message ("Your skill in Tailoring has increased"). **In-game** (Era).
- **Profession Journal turned off (review #12).** With the Profession Journal toggle off, its route-only materials stayed in the Materials tree, in `/kt find` and in stock tracking until a reload.
  - Now they leave at once and come back when the toggle is turned on again. Stock keeps recording them while it is off (stock records materials whatever the settings mark), so totals stay right when it is turned back on. **In-game** (Forever, with Profession Journal).
- **Intermediate shares (review #21).** The "Includes N for X" lines took each intermediate's largest share across the guides, so two lines could add up to more than the count shown (Forever Engineering at 106: Copper Bar 59-62, includes 59 for Bronze Bar and 13 for Handful of Copper Bolts).
  - Now the shares come from the guide that gives the top of the range, so they never add up to more than it. **Unit**, with the shipped Forever data.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `leveling-guidance`:
  - "Count to keep" gains scenarios for a collapsed Skills header.
  - "Counts never block marking" covers a source whose remaining steps have no count.
  - "Profession Journal adds to the sources when installed" covers turning it off.
  - New requirement: intermediate shares stay within the count.
## Impact

- **Code:**
  - `Model/Leveling.lua` (`Need`: counted sources, shares)
  - `Core/Adapter.lua` (`ProfessionSkills`: expand, read, restore)
  - `Core/Addon.lua` and `Core/Context.lua` (refresh only when ranks change)
  - `Integrations/ProfessionJournal.lua` (`Items` follows the toggle)
  - `Options/Options.lua` (tree rebuild follows the toggle)
- **Tests:** `test_leveling`, `test_adapter`, `test_context` or `test_addon`, `test_professionjournal`, `test_options`, `test_auctionator`, `test_wording`.
- **Docs:**
  - `docs/test-plan.md` (section 13, two checks)
  - `docs/contracts.md` (Era Skills list shows only expanded rows)
  - `README.md` "Good to know", if it mentions the Skills tab or Profession Journal toggle.
- **Saved data:** no format change.
- **Release:** patch, 0.4.7.
