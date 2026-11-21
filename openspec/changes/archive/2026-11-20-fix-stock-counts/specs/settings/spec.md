# Spec Delta

## MODIFIED Requirements

### Requirement: Material stock on its page
Each material page SHALL keep its "Your stock" section. It SHALL give the realm-and-faction total split between this character and the player's other characters, then one line per character holding any: this character first, then the others by count, each other character with the grey age of its oldest counted source. Every holder SHALL be listed, and the page SHALL NOT ask the player to open a bank or mailbox. When nobody holds the material, the section SHALL say the player has none only when the total is complete, and otherwise that none is counted yet.

#### Scenario: Stock across characters
- **WHEN** a route still needs 40 Runecloth, this character has 12 in bags and 8 in the bank, Bankmule has 30 in the bank, Hunter has 5 in the mailbox, and every bank and mailbox is counted
- **THEN** the page shows `55 owned - 20 on this character, 35 on your other characters`, a line for each of the three characters, and "You have enough."

#### Scenario: Nobody holds it
- **WHEN** no character in scope holds the material and every bank and mailbox is counted
- **THEN** the section says the player has none, with no per-character lines

#### Scenario: Nobody holds it so far
- **WHEN** no counted source holds the material and some bank or mailbox in scope is not counted
- **THEN** the section says `None counted yet.`, with no per-character lines
