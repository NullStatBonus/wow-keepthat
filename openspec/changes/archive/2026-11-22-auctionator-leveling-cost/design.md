# Design

## Context

See proposal.md for motivation. `Auctionator.Materials(profession, "leveling")` already returns `{ itemID, quantity }` rows, where `quantity` is the count still needed after the realm-and-faction stock. `Export` builds the list from the same rows. Every Auctionator call runs through `api()` and `pcall`, and an error turns the integration off for the session (`failure()`).

Measured from a public fork of Auctionator's source (not yet on build 347, see Open Questions):

- `GetAuctionPriceByItemID(callerID, itemID)` returns the last scanned price in copper, or nil.
- `GetAuctionAgeByItemID(callerID, itemID)` returns days since the item was last seen, or nil when never seen or older than 21 days.
- A bad `callerID` raises an error. We already use `"KeepThat"`.

## Goals / Non-Goals

**Goals:**
- Show a leveling cost estimate under the leveling export button, behind one off-by-default setting.
- Never count an unknown or stale price as 0.

**Non-Goals:**
- Endgame estimate (needs quantities, issue #10; its toggle comes then).
- Price history, vendor or disenchant prices, caching, or a price column in the Materials tree.
- Reading Auctionator's database or the Profession Journal's saved prices.

## Decisions

**D1. Estimate in `Integrations/Auctionator.lua`.** Add `Auctionator.Estimate(profession)` that walks `Materials(profession, "leveling")` and returns `{ copper, priced, unknown }`. It takes the price lookup through the same `api()` table, so tests pass a fake. No new Model file. Alternative, a Model module, adds a file for one loop.

**D2. A price counts only with a fresh age.** Use the price when both the price and the age are numbers. Nil age means never seen or older than 21 days, so the price is unknown. This reuses Auctionator's own cutoff instead of inventing one. A row with no `quantity` counts as unknown.

**D3. Partial wording.** Three states: all known ("Estimated cost: %s, from Auctionator's last scan."), some unknown ("At least %s from Auctionator's last scan. %d materials have no recent price."), none known ("No recent Auctionator price for these materials."). Every sentence is one `L["..."]` key. Money is shown as gold and silver, rounded up to the next silver.

**D4. Failure handling.** The estimate needs both price functions. If either is missing, `EstimateAvailable()` is false and no line shows. An error in a call sets `Auctionator.estimateFailed`, logs through `ns.Log.Failure("auctionator-estimate", err)`, and stops only the estimate. The export keeps working.

**D5. Setting and place.** New profile key `estimateLevelingCost = false` (flat, not under `integrations`, so the Integrations list and its status rows stay unchanged). The toggle goes on the Integrations page right under the Auctionator row, disabled with a reason when the integration is off, Auctionator is missing, or the client is Classic Era. The estimate line is a `description` under the leveling export button, hidden when the setting is off or the list is empty. Alternative: a toggle on each profession page. Rejected as more controls for one setting.

**D6. Compute when drawn.** The line is a function evaluated when the page draws. It makes one price call and one age call per listed material and keeps nothing. A page redraw repeats them, which is cheap for a list this size.

**D7. Debug report.** `Debug/Log.lua` lists `estimateLevelingCost` with its value and `estimateFailed` when set.

**D8. Tooltip cost line.** `Wording.Details` takes an optional `ctx.cost(itemID, profession)` that returns `{ quantity, copper }`, `{ quantity }` (no price), or nil. The Auctionator integration supplies it only while the setting is on and the estimate is available. `Model/Wording.lua` stays plain Lua and never names Auctionator. The line goes directly below the count line of the leveling block. The quantity is the export quantity from `Materials`, so the line and the export agree. Estimate and tooltip share one price lookup. Alternative: show the cost on the default line. Rejected: it adds noise to every hover.

## Risks / Trade-offs

- The price functions come from a fork of the source. The probe in task 1 confirms them on build 347. If `GetAuctionPriceByItemID` is missing, the change stops there and issue #9 closes with the finding.
- Scan prices lag the auction house, so the estimate can be low or high. The wording says so, and the 21-day cutoff drops very old prices.
- Tooltip hovers call the price functions once per Shift redraw. That is two table lookups per material.
- The Integrations toggle adds one control to a page of toggles. Codex visual review checks the layout before it ships.

## Open Questions

- Does `GetAuctionAgeByItemID` exist and return days on build 347? If not, decide between counting the price without an age or turning the estimate off. The probe answers it.
