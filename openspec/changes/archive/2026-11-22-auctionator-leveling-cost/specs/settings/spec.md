# Spec Delta

## ADDED Requirements

### Requirement: Estimate leveling cost setting
The Integrations page SHALL give the Auctionator row a toggle, "Estimate leveling cost", off by default. It SHALL turn on both the profession-page estimate and the Shift tooltip cost line, and its help text, shown only while it is enabled, SHALL say so. It SHALL be disabled with a short reason when the estimate cannot work (Classic Era, integration off, Auctionator missing or without prices, or an earlier error). A change SHALL take effect without a reload. The debug report SHALL list its value.

#### Scenario: Default off
- **WHEN** a player installs the addon or updates from a version without this setting
- **THEN** the setting is off and no estimate shows

#### Scenario: Turned on
- **WHEN** Auctionator is available and the player turns the setting on
- **THEN** each profession page with leveling materials shows the estimate below the leveling export button without a reload

#### Scenario: Tooltip follows the setting
- **WHEN** the player turns the setting on and holds Shift over a leveling material that is still needed
- **THEN** its leveling block shows the cost line, and turning the setting off removes it

#### Scenario: Integration off
- **WHEN** the player turns the Auctionator integration off
- **THEN** the setting is disabled, says why, and no estimate shows

#### Scenario: Debug report
- **WHEN** the player types `/kt log`
- **THEN** the report lists the value of the setting
