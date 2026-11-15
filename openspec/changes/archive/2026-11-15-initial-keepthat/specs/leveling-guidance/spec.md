# Spec Delta

## Purpose

Defines which materials KeepThat marks for leveling and how many it says to keep. The data comes from the common free leveling guides for each client, without the player having to choose a route. DFL Profession Journal adds to it when installed.

## ADDED Requirements

### Requirement: Leveling materials from the common guides
For each client and crafting profession, the addon SHALL ship the materials used by the 1-300 routes of the cited free guides for that client. A material SHALL be a leveling material when at least one cited guide uses it. Paid guides SHALL NOT be used as sources.

#### Scenario: Material used by one guide only
- **WHEN** one cited Classic Era Tailoring guide uses Bolt of Silk Cloth and another does not
- **THEN** Bolt of Silk Cloth is a Tailoring leveling material on Classic Era

#### Scenario: Different clients
- **WHEN** the WoW Forever guides use a material that no Classic Era guide uses
- **THEN** it is a leveling material on WoW Forever only

### Requirement: Inputs of intermediate materials
When a guide's route needs a material that a recipe makes, and the route does not itself craft enough of it, the shortfall's inputs SHALL also be leveling materials for that guide, recursively, over the same skill range. Each SHALL record the material it is used to make. The same expansion rules as the catalog apply: a material made by exactly one recipe that is not an element conversion.

#### Scenario: Bars from ore
- **WHEN** a Blacksmithing route needs 150 Copper Bar and crafts none, and only smelting makes Copper Bar from Copper Ore
- **THEN** Copper Ore is a leveling material with a count of 150, recorded as used to make Copper Bar

#### Scenario: Route already crafts the intermediate
- **WHEN** a Tailoring route needs 237 Bolt of Runecloth and its own steps craft 239 of them
- **THEN** no extra Runecloth is added for the bolts, beyond what the bolt steps already need

#### Scenario: Partial shortfall
- **WHEN** a route needs 100 of an intermediate and its own steps craft 60
- **THEN** inputs are added for the remaining 40 only

### Requirement: No route choice
The addon SHALL NOT ask the player to choose a leveling route or guide. Leveling marks and counts SHALL come from all cited guides together.

#### Scenario: Fresh install
- **WHEN** the player turns on leveling materials
- **THEN** leveling materials are marked with no further choice to make

### Requirement: Count to keep
When the player knows the profession, each source's count is what its route still needs from the player's current skill to 300. When the player does not know the profession, the count is for the whole route from skill 1. A source may give a range itself, for example a guide that lists "100-120 Wool Cloth" for a block of skill. The addon SHALL show one number when all sources agree. Otherwise it SHALL show a range to keep on hand, from the smallest to the largest count among the sources.

#### Scenario: Guides agree
- **WHEN** from the player's current skill both guides need 40 Bolt of Runecloth
- **THEN** the count shown is `40`

#### Scenario: Guides differ
- **WHEN** from the player's current skill one guide needs 40 Bolt of Runecloth and another needs 55
- **THEN** the count shown is the range `40-55`

#### Scenario: A guide gives a range
- **WHEN** one guide needs 100-120 Wool Cloth and another needs 110
- **THEN** the count shown is `100-120`

#### Scenario: Partway through
- **WHEN** the player's Tailoring is 270 and a guide uses a material only in steps from 260 to 280
- **THEN** that guide contributes only what its steps from 270 to 280 need

#### Scenario: Steps passed in every guide
- **WHEN** the player's skill is above every step that uses a material in every source
- **THEN** that material is not marked as a leveling material for that player

#### Scenario: Profession not known
- **WHEN** the player does not know the profession
- **THEN** the count shown is for the whole route from skill 1

### Requirement: Counts name their sources
The details for a leveling material SHALL name the guides that use it.

#### Scenario: Details with Shift
- **WHEN** the player holds Shift over a leveling material used by two guides
- **THEN** the details name both guides

### Requirement: Works without other addons
Leveling marks and counts SHALL be complete with no other addon installed.

#### Scenario: No guide addon installed
- **WHEN** no guide addon is installed
- **THEN** every crafting profession on the running client has leveling materials and counts

### Requirement: Profession Journal adds to the sources when installed
When DFL Profession Journal is installed and its route data can be read, its route SHALL count as one more source: its materials become leveling materials, and its counts take part in the range. Its data SHALL never be copied into the addon's files or saved variables.

#### Scenario: Profession Journal needs more
- **WHEN** Profession Journal is installed and its route needs more of a material from the current skill than any built-in guide
- **THEN** the top of the range shown is Profession Journal's count, and the details name Profession Journal

#### Scenario: Profession Journal unreadable
- **WHEN** Profession Journal is loaded but its data cannot be read or has an unexpected shape
- **THEN** only the built-in sources are used, no error is shown, and the debug report records why

### Requirement: Counts never block marking
Missing count data SHALL NOT stop an item from being marked; the details SHALL then omit the count.

#### Scenario: No count for a material
- **WHEN** a leveling material has no count in any source
- **THEN** it is still marked, and the details show its skill range without a count
