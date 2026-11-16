## MODIFIED Requirements

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
