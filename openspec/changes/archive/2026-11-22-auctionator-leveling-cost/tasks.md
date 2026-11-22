# Tasks

## 1. Probe Auctionator on WoW Forever

- [x] 1.1 Extend `Debug/Probe.lua` to list the `Auctionator.API.v1` price and age functions and log one sample call for a material that has a price.
- [x] 1.2 Record the result, build and date in `docs/contracts.md`. Stop and close #9 with the finding if `GetAuctionPriceByItemID` is missing. (Both price functions exist on Auctionator 351; sample values still to read from `/kt probe`.)

## 2. Estimate logic

- [x] 2.1 Add the `estimateLevelingCost = false` default in `Core/Defaults.lua`.
- [x] 2.2 Add `Auctionator.Estimate` and `EstimateAvailable` in `Integrations/Auctionator.lua` (D1, D2, D4), plus the gold-and-silver formatter.
- [x] 2.3 Add `ctx.cost` to `Model/Wording.lua` and `UI/Tooltip.lua` (D8): the shortfall line, the no-price line, and no line when off, covered or without a count. Tests go in `tests/test_tooltip.lua`.
- [x] 2.4 Add tests in `tests/test_auctionator.lua`: all known, some unknown, none known, stale price, missing quantity, missing function, function error with the export still working, Classic Era. Break each behavior once and confirm the test fails.

## 3. Settings and report

- [x] 3.1 Add the toggle under the Auctionator row and the estimate line under the leveling export button in `Options/Options.lua` (D5), with the disabled reasons.
- [x] 3.2 Add the setting and `estimateFailed` to the debug report in `Debug/Log.lua`. Check with `/kt log`.
- [x] 3.3 Add the new sentences to the locale files and run `tests/test_locale.lua`.
- [x] 3.4 Use the setting help text "Select Estimate leveling cost to see the profession total. Hold Shift over a material to see its estimated shortfall cost."
- [x] 3.5 Ask Codex to review the toggle, the estimate line and the tooltip cost line.

## 4. Docs and checks

- [x] 4.1 Update `README.md` (Auctionator section, Good to know, Integrations page), `docs/listing.md` and `tests/test_readme.lua` if the command list changes.
- [x] 4.2 Add at most two in-game checks to `docs/test-plan.md` section 5: with the setting on, the profession page shows the estimate, and Shift over a needed material shows its cost line. Add a `Log:` line for the reviewer.
- [x] 4.3 Run `make test` and `make check`.
