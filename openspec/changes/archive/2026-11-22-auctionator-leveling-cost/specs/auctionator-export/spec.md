# Spec Delta

## ADDED Requirements

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
