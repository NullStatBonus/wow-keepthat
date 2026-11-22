# Spec Delta

## ADDED Requirements

### Requirement: Shortfall cost in the leveling details
While Shift is held and the leveling cost estimate setting is on, the leveling block of a material SHALL show one neutral line directly below the count line: `Estimated cost for <N>: <amount>, from Auctionator's last scan.`. N SHALL equal the quantity the leveling export uses. When Auctionator has no recent price, the line SHALL read `No recent Auctionator price for this item.`, and an unknown price SHALL NOT count as zero.

#### Scenario: Price known
- **WHEN** the setting is on, the route needs 40 Runecloth, the realm-and-faction total is 12, Runecloth is priced 50 silver, and the player holds Shift
- **THEN** the line below the count reads `Estimated cost for 28: 14g, from Auctionator's last scan.`

#### Scenario: Price unknown
- **WHEN** the setting is on, 28 are still needed and Auctionator has no recent price
- **THEN** the line below the count reads `No recent Auctionator price for this item.`

### Requirement: No cost line when there is nothing to price
The leveling block SHALL show no cost line when the setting is off, when Auctionator is not available, when the realm-and-faction total covers the count still needed, or when the count still needed is unknown. The default line SHALL stay the same.

#### Scenario: Already covered
- **WHEN** the setting is on and the realm-and-faction total covers the count still needed
- **THEN** the leveling block shows no cost line

#### Scenario: Setting off
- **WHEN** the setting is off
- **THEN** the leveling block shows no cost line

#### Scenario: Default line unchanged
- **WHEN** the setting is on and Shift is not held
- **THEN** the tooltip shows the same single line as before, with no cost
