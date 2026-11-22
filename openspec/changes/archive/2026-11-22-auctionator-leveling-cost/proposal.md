# Proposal

## Why

Players who buy leveling materials through the Auctionator shopping list cannot see what the list will cost before they open the auction house. Issue #9 asks for an optional estimate, built from Auctionator's last scan.

## What Changes

- Add an optional gold estimate for the leveling materials still needed, shown under the "Export leveling list" button on each profession page.
- Add one setting, "Estimate leveling cost", off by default. It sits on the Integrations page under the Auctionator row and works only while the Auctionator integration is on. The same setting drives the profession page and the Shift tooltip.
- While Shift is held, show the cost of the hovered leveling material's shortfall in its leveling block, with the same unknown-price rules.
- Read each price with Auctionator's documented price function. An unknown or stale price is never counted as 0. A total with any unknown price is shown as partial, with the number of materials left out.
- Word the estimate as a guide taken from Auctionator's last scan, not a promised price or quantity.
- Record the Auctionator price functions in `docs/contracts.md` after a game probe, and add the setting to the README, the debug report, the listing text and the test plan.
- Leave the endgame estimate out. Endgame lists carry no quantities (issue #10). Its own setting, "Estimate endgame cost", comes with that work.
- Leave stock placement alone. Moving the owned total under Shift is a separate change (new issue).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `auctionator-export`: add the leveling cost estimate, its unknown-price rules and its wording.
- `material-tooltip`: add the shortfall cost line in the Shift details.
- `settings`: add the "Estimate leveling cost" setting, its default, its place on the Integrations page and its line in the debug report.

## Impact

- `KeepThat/Integrations/Auctionator.lua`: price lookup and estimate.
- `KeepThat/Options/Options.lua`: the toggle and the estimate line.
- `KeepThat/Model/Wording.lua`, `KeepThat/UI/Tooltip.lua`: the shortfall cost line (a `ctx.cost` input, nil when the setting is off).
- `KeepThat/Core/Defaults.lua`, `KeepThat/Debug/Log.lua`, `KeepThat/Debug/Probe.lua`, the locale files.
- Docs: `README.md`, `docs/listing.md`, `docs/test-plan.md`, `docs/contracts.md`.
- Tests: `tests/test_auctionator.lua`, plus the README and locale checks.
- No saved-data break. The new setting has a default.
