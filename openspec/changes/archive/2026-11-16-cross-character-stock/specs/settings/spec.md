## MODIFIED Requirements

### Requirement: Defaults
A new install SHALL default to: endgame materials on, leveling materials off, tooltip line on, loot toast off, login reminder on, icon mask off, endgame color purple, leveling color green, and "Show marks in" with bags, bank and merchant checked.

#### Scenario: First login
- **WHEN** the addon loads with no saved settings
- **THEN** every setting has the default listed above

### Requirement: Material stock on its page
Each material page SHALL keep its "Your stock" section. The section SHALL first give the realm-and-faction total, split between this character and the player's other characters (`55 owned - 20 on this character, 35 on your other characters`). Then it SHALL give one line per character holding any: this character first (`This character: 12 in bags, 8 in the bank`), then the others by count, each with the age of its oldest counted source (`Bankmule: 30 in the bank (3 days ago)`). The age SHALL be grey. Every character holding any SHALL be listed. The page SHALL NOT ask the player to open a bank or mailbox.

A leveling page SHALL also show how many are still to get: the count still needed minus the realm-and-faction total, as a range when the guides differ, or that the player has enough. While the total is incomplete, the still-to-get line SHALL be hidden. An endgame page SHALL show what each leveling route still needs of the item when it is also a leveling material.

#### Scenario: Stock across characters
- **WHEN** a route still needs 40 Runecloth, this character has 12 in bags and 8 in the bank, Bankmule has 30 in the bank, Hunter has 5 in the mailbox, and every bank and mailbox is counted
- **THEN** the page shows `55 owned - 20 on this character, 35 on your other characters`, a line for each of the three characters, and "You have enough."

#### Scenario: Leveling material with some in the bank
- **WHEN** a route still needs 40 Linen Cloth, the player has 10 in bags and 15 in the bank, no other character holds any, and every bank and mailbox is counted
- **THEN** the page shows `This character: 10 in bags, 15 in the bank` and "Still to get: 15"

#### Scenario: Enough on hand
- **WHEN** the total is at least the top of the range and every bank and mailbox is counted
- **THEN** the page says "You have enough."

#### Scenario: Incomplete total
- **WHEN** a route still needs 40 Linen Cloth and another character's mailbox has not been counted
- **THEN** the still-to-get line is hidden and no note explains why

#### Scenario: Nobody holds it
- **WHEN** no character in scope holds the material
- **THEN** the section says the player has none, with no per-character lines

## ADDED Requirements

### Requirement: Login reminder setting
Home SHALL have a "Login reminder" checkbox under "Where to show it", after "Loot toast" and before "Icon tint". Its hover text SHALL be "Remind you at login when a character's bank or mailbox is not counted." It SHALL control the character-stock login reminder and SHALL be the same setting as `/kt set stock.reminder`. The "displays are off" note on Home SHALL NOT consider it.

#### Scenario: Turn the reminder off
- **WHEN** the player clears "Login reminder" on Home
- **THEN** `/kt get stock.reminder` returns `off` and no reminder prints at the next login
