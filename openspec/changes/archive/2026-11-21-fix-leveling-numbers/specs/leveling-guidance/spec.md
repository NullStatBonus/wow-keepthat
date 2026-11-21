## MODIFIED Requirements

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

#### Scenario: Skills header collapsed on Classic Era
- **WHEN** the player knows Tailoring at 150 on Classic Era and has collapsed the Professions header on the Skills tab
- **THEN** the count is for Tailoring's steps from 150, not the whole route, and the header is still collapsed afterwards

### Requirement: Counts never block marking
Missing count data SHALL NOT stop an item from being marked; the details SHALL then omit the count. A source whose remaining steps that use the material give no count SHALL take no part in the count, even when its passed steps had one; it SHALL never report a count of 0 for steps still ahead.

#### Scenario: No count for a material
- **WHEN** a leveling material has no count in any source
- **THEN** it is still marked, and the details show its skill range without a count

#### Scenario: Only uncounted steps left in a source
- **WHEN** a source's only steps with a count for a material are passed, its later steps that use the material give no count, and no other source has a count
- **THEN** the details show the skill range without a count, the material page does not say "You have enough.", and the Auctionator list includes the material without a quantity

#### Scenario: A finished guide next to uncounted steps
- **WHEN** one guide's steps for a material are all passed and Profession Journal's only steps ahead give no count
- **THEN** the details show no count, not `0`

#### Scenario: Another source still has a count
- **WHEN** one source has only uncounted steps left for a material and another source still needs 40
- **THEN** the count shown is `40`

### Requirement: Profession Journal adds to the sources when installed
When DFL Profession Journal is installed and its route data can be read, its route SHALL count as one more source: its materials become leveling materials, and its counts take part in the range. Its data SHALL never be copied into the addon's files or saved variables.

#### Scenario: Profession Journal needs more
- **WHEN** Profession Journal is installed and its route needs more of a material from the current skill than any built-in guide
- **THEN** the top of the range shown is Profession Journal's count, and the details name Profession Journal

#### Scenario: Profession Journal unreadable
- **WHEN** Profession Journal is loaded but its data cannot be read or has an unexpected shape
- **THEN** only the built-in sources are used, no error is shown, and the debug report records why

#### Scenario: Profession Journal turned off
- **WHEN** the player turns off Profession Journal on the Integrations page
- **THEN** materials only its route uses leave the Materials tree, `/kt find` and the counts at once, without a reload, and come back when it is turned on again

## ADDED Requirements

### Requirement: Intermediate shares stay within the count
The share of a material that goes into an intermediate ("Includes 59 for Bronze Bar") SHALL come from the source that gives the top of the count. The shares shown for one material SHALL never add up to more than the top of its count.

#### Scenario: Two intermediates
- **WHEN** on WoW Forever with Engineering at 106, Copper Bar is needed for Bronze Bar and Handful of Copper Bolts and the count is `59-62`
- **THEN** the "Includes" shares shown add up to 62 or less
