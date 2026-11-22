# auctionator-export Specification

## Purpose

Lets the player turn the materials they still need into an Auctionator shopping list, so buying them at the auction house takes one search instead of many.

## Requirements

### Requirement: Export a shopping list for a profession
When Auctionator is loaded, the player SHALL be able to export the enabled materials of one profession and category (endgame or leveling) as an Auctionator shopping list named `KeepThat: <Profession> <Category>`.

#### Scenario: Export leveling materials
- **WHEN** Auctionator is loaded and the player exports Tailoring leveling materials
- **THEN** Auctionator has a shopping list `KeepThat: Tailoring Leveling` with one search per enabled Tailoring leveling material that is still needed

#### Scenario: Export endgame materials
- **WHEN** the player exports Blacksmithing endgame materials
- **THEN** the list has one search per enabled Blacksmithing endgame material

### Requirement: Only what is still needed
For leveling materials with a known count, the list SHALL include only those where the count still needed is more than the realm-and-faction total, and SHALL set the quantity to the difference when Auctionator accepts a quantity. The total SHALL be used as counted, even when it is incomplete.

#### Scenario: Already carrying enough
- **WHEN** the route needs 40 Bolt of Runecloth from the player's skill and the player carries 40
- **THEN** Bolt of Runecloth is not in the exported list

#### Scenario: Enough on other characters
- **WHEN** the route needs 40 Runecloth, this character carries 12 and Bankmule's bank holds 30
- **THEN** Runecloth is not in the exported list

#### Scenario: Part held elsewhere
- **WHEN** the route needs 40 Runecloth and the realm-and-faction total is 25
- **THEN** Runecloth is in the list with quantity 15

### Requirement: Re-export replaces the list
Exporting the same profession and category again SHALL replace the earlier KeepThat list of that name and SHALL NOT touch any other shopping list.

#### Scenario: Export twice
- **WHEN** the player exports Tailoring leveling materials twice
- **THEN** Auctionator has one `KeepThat: Tailoring Leveling` list reflecting the second export, and the player's own lists are unchanged

### Requirement: Unavailable without Auctionator
When Auctionator is not loaded, or its interface cannot be used, the export control SHALL be disabled with a short reason, and nothing SHALL error.

#### Scenario: Auctionator missing
- **WHEN** Auctionator is not installed
- **THEN** the export control is disabled and says that Auctionator is needed

### Requirement: Estimated cost of the leveling materials
While Auctionator is available and the leveling cost estimate setting is on, the profession page SHALL show an estimated cost for the leveling list: the sum of price times quantity still needed over its materials, with prices from Auctionator's last scan.

#### Scenario: All prices known
- **WHEN** the leveling list needs 20 Runecloth priced 50 silver and 10 Mageweave Cloth priced 1 gold, and the setting is on
- **THEN** the page shows an estimate of 20 gold

### Requirement: Unknown prices
A price Auctionator has no value for, or reports as too old, SHALL count as unknown and SHALL NOT count as zero. A material with no quantity still needed SHALL count as unknown. A total with unknown parts is a lower bound, so it SHALL be rounded down to the silver, and an exact total SHALL be rounded up.

#### Scenario: Some prices unknown
- **WHEN** the leveling list has three materials and Auctionator has no recent price for one of them
- **THEN** the page shows the sum of the other two as "at least" that amount and says one material could not be priced

#### Scenario: No prices known
- **WHEN** Auctionator has no recent price for any material in the list
- **THEN** the page shows no amount and says no cost estimate is available for these materials

### Requirement: Estimate wording
The estimate SHALL say it comes from Auctionator's last scan and SHALL NOT present it as a guaranteed price or as an available quantity.

#### Scenario: Wording
- **WHEN** an estimate is shown
- **THEN** the text names Auctionator's last scan as its source

### Requirement: Estimate never breaks the export
The estimate SHALL NOT change which searches the export creates. If Auctionator's price functions are missing, the estimate SHALL be unavailable with its reason shown on the Integrations page. If a price call raises an error, the estimate SHALL turn itself off for the session with the error in the debug report. The export SHALL keep working in both cases.

#### Scenario: Price function missing
- **WHEN** Auctionator is loaded but has no price function
- **THEN** no estimate is shown, the Integrations page gives the reason, and the leveling export still creates its list

#### Scenario: Price function raises an error
- **WHEN** a price call raises an error
- **THEN** the estimate stops for the session, the debug report records the error, the export still works, and nothing errors in chat

### Requirement: Estimate on WoW Forever only
The estimate SHALL NOT run on Classic Era, like every integration.

#### Scenario: Classic Era
- **WHEN** the client is Classic Era
- **THEN** no estimate is shown
