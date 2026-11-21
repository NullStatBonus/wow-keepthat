# character-stock Specification

## Purpose
Records each character's stock of catalog and route materials (bags, bank and mailbox), totals it across the characters on the current realm and faction, expires old records, and reminds the player when a bank or mailbox is not counted yet.

## Requirements

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

### Requirement: Readings replace whole containers
Each reading of a bag, bank container or the inbox SHALL replace that container's whole record, never add or subtract, so a stack moved between sources is counted once. A failed or incomplete reading of a container SHALL keep that container's previous record and age. A source SHALL count as counted only when every container it expects has a record.

#### Scenario: Deposit into the bank
- **WHEN** the player moves 10 Runecloth from bags to the bank with the bank open
- **THEN** the records show 10 fewer in bags and 10 more in the bank, and the total is unchanged

#### Scenario: Taking mail
- **WHEN** the player takes 5 Runecloth from a mail
- **THEN** the mailbox record drops by 5 and the bags record rises by 5

#### Scenario: Failed reading
- **WHEN** reading one bank bag fails while the others succeed
- **THEN** that bag keeps its previous record and age, and the others update

### Requirement: Realm and faction scope
Totals and lists SHALL include only characters on the current character's realm and faction. Characters on other realms or factions SHALL keep their records, which SHALL NOT be shown or counted.

#### Scenario: Other faction
- **WHEN** a Horde character on the same realm holds 30 Runecloth and the current character is Alliance
- **THEN** those 30 are not counted or listed

### Requirement: Realm-and-faction total
The total of a material SHALL be the sum, over every counted character in scope, of every source that has been counted. A source that is not counted or unavailable SHALL add nothing. The total SHALL be complete only when every character in scope has its bags, bank and mailbox counted. An unknown count SHALL never count as 0. A source the client cannot read SHALL NOT make the total incomplete.

#### Scenario: Total across characters
- **WHEN** this character has 12 in bags and 8 in the bank, Bankmule has 30 in the bank and Hunter has 5 in the mailbox
- **THEN** the total is 55

#### Scenario: Incomplete total
- **WHEN** Bankmule's mailbox has never been counted
- **THEN** the total sums what is counted and is marked incomplete

### Requirement: Expiry after 90 days
A character not seen for 90 days or more SHALL be left out of every total, list and reminder. Its record SHALL be deleted at the next login of any character. A bank or mailbox record older than 90 days SHALL count as not counted. A character is seen each time it logs in with KeepThat. Each source keeps the time it was last read. A clock reading earlier than a saved time SHALL count as that saved time.

#### Scenario: Character not seen for 100 days
- **WHEN** Bankmule last logged in 100 days ago
- **THEN** its stock is not counted or listed, and its record is deleted

#### Scenario: Old bank record
- **WHEN** a character logs in daily but last opened its bank 120 days ago
- **THEN** its bank counts as not counted, and the reminder includes it

### Requirement: Login reminder
While the login reminder setting is on (the default), KeepThat SHALL print one chat line at each login or reload when any character in scope, the current one included, has a bank or mailbox not counted. The line SHALL give only the number of characters and point to `/kt status stock`. It SHALL be silent when nothing is missing. A source the client cannot read is not missing. The reminder SHALL be the only place that asks the player to open a bank or mailbox.

#### Scenario: Two characters missing a source
- **WHEN** a character logs in and Bankmule's mailbox and Hunter's bank are not counted
- **THEN** chat shows `KeepThat: 2 characters have a bank or mailbox not counted. /kt status stock lists them.`

#### Scenario: One character missing a source
- **WHEN** only the current character's bank is not counted
- **THEN** chat shows `KeepThat: 1 character has a bank or mailbox not counted. /kt status stock lists it.`

#### Scenario: Reminder off
- **WHEN** the login reminder setting is off
- **THEN** no reminder is printed at login

#### Scenario: Everything counted
- **WHEN** every character in scope has its bank and mailbox counted
- **THEN** no reminder is printed

### Requirement: Character names and realms on WoW Forever
A character's stock SHALL be filed under its realm's name, never its surname. When the client uses surnames, a character SHALL be named by its first name and surname, so two characters sharing a first name are counted separately. Where the client does not use surnames, characters SHALL be named and filed exactly as before.

#### Scenario: Alts with different surnames share a total
- **WHEN** two WoW Forever characters on the same realm and faction have different surnames and both have logged in
- **THEN** each one's total includes the other's counted sources, and `/kt status stock` names the realm

#### Scenario: Same first name, different surnames
- **WHEN** two WoW Forever characters on the same realm and faction share a first name
- **THEN** each has its own stock record and its own line in the stock details

#### Scenario: Classic Era unchanged
- **WHEN** a Classic Era character logs in
- **THEN** its stock is filed under the same realm and name as before, and saved stock is left exactly as it was

### Requirement: Earlier Forever stock records are moved once
At login, a WoW Forever character's stock record saved under its surname as the realm and its first name as the name SHALL be moved to its realm and full name, keeping every source and time. The move SHALL happen only when no record exists under the new realm and name. Records of characters that have not logged in since SHALL stay where they are until they do or until they expire.

#### Scenario: First login after the update
- **WHEN** a WoW Forever character with a record saved under its surname logs in
- **THEN** its record is found under its realm and full name with the same counts, and the record under its surname is gone

#### Scenario: Record already under the new name
- **WHEN** records exist under both the surname and the realm for the character
- **THEN** the record under the realm is kept unchanged
