# Spec Delta

## ADDED Requirements

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
