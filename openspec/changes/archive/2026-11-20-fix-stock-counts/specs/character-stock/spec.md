# Spec Delta

## MODIFIED Requirements

### Requirement: Stock recorded per character
KeepThat SHALL record, per character, how many of each catalog and route material that character holds in each of three sources: bags, bank and mailbox. Route materials SHALL include those of Profession Journal's route while it is installed and readable. It SHALL record these materials whatever the settings mark. It SHALL never record the guild bank. It SHALL save the records for the whole account. A source that has never been read SHALL be recorded as not counted, which is distinct from a count of 0.

#### Scenario: Bags at login
- **WHEN** a character logs in carrying 12 Runecloth
- **THEN** that character's bags record shows 12 Runecloth

#### Scenario: Material not marked by the settings
- **WHEN** leveling marks are off and a character's bank holds Runecloth, a route material
- **THEN** that character's bank record still shows the Runecloth

#### Scenario: Material only Profession Journal's route uses
- **WHEN** Profession Journal is installed and a character's bank holds a material only its route uses
- **THEN** that character's bank record shows the material once the bank is read

#### Scenario: Guild bank
- **WHEN** the player opens the guild bank, which holds Runecloth
- **THEN** no record changes

#### Scenario: Bank never opened
- **WHEN** a character has never opened its bank with KeepThat installed
- **THEN** that character's bank is recorded as not counted, not as 0

### Requirement: Sources read while open
The bank SHALL be read when the bank window opens and re-read while it stays open. The mailbox SHALL be read when its inbox loads and re-read while it stays open. When a window closes, the last reading SHALL be kept. A change to a bank container or the inbox that the game reported but KeepThat had not yet read when its window closed, or that the game reports within 10 seconds after it closed, SHALL make that container, or the mailbox, not counted until it is read again, so a stale reading is never counted. A source the client cannot read SHALL be recorded as unavailable, which is distinct from not counted.

#### Scenario: Bank closed
- **WHEN** the player closes the bank after it was read
- **THEN** the bank record keeps that reading

#### Scenario: Withdraw and close at once
- **WHEN** the player takes 18 Runecloth from the bank into bags holding 2 and closes the bank before the game reports the bank change
- **THEN** the total is never 38: the bags count 20 and that bank container is not counted until the bank is opened again

#### Scenario: Take mail and close at once
- **WHEN** the player takes 5 Runecloth from a mail and closes the mailbox before the game reports the inbox change
- **THEN** the 5 are counted once, in bags, and the mailbox is not counted until it is opened again
