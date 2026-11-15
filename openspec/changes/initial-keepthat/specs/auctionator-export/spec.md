# Spec Delta

## Purpose

Lets the player turn the materials they still need into an Auctionator shopping list, so buying them at the auction house takes one search instead of many.

## ADDED Requirements

### Requirement: Export a shopping list for a profession
When Auctionator is loaded, the player SHALL be able to export the enabled materials of one profession and category (endgame or leveling) as an Auctionator shopping list named `KeepThat: <Profession> <Category>`.

#### Scenario: Export leveling materials
- **WHEN** Auctionator is loaded and the player exports Tailoring leveling materials
- **THEN** Auctionator has a shopping list `KeepThat: Tailoring Leveling` with one search per enabled Tailoring leveling material that is still needed

#### Scenario: Export endgame materials
- **WHEN** the player exports Blacksmithing endgame materials
- **THEN** the list has one search per enabled Blacksmithing endgame material

### Requirement: Only what is still needed
For leveling materials with a known count, the list SHALL include only those where the count still needed is more than the player carries, and SHALL set the quantity to the difference when Auctionator accepts a quantity.

#### Scenario: Already carrying enough
- **WHEN** the route needs 40 Bolt of Runecloth from the player's skill and the player carries 40
- **THEN** Bolt of Runecloth is not in the exported list

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
