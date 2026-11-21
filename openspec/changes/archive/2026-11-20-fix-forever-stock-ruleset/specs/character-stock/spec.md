# Spec Delta

## MODIFIED Requirements

### Requirement: Character names and realms on WoW Forever
A character's stock SHALL be filed under its realm, never its surname. When the client uses surnames, a character SHALL be named by its first name and surname, so two characters sharing a first name are counted separately, and its realm SHALL be its ruleset (PvE, PvP, RP, RP-PvP or Hardcore), the same realm the settings library uses, because that client has no realm names. Where the client does not use surnames, characters SHALL be named and filed exactly as before.

#### Scenario: Alts with different surnames share a total
- **WHEN** two WoW Forever characters on the same ruleset and faction have different surnames and both have logged in
- **THEN** each one's total includes the other's counted sources, and `/kt status stock` names the ruleset, such as `Stock: 2 characters on PvE (Alliance).`

#### Scenario: No realm name at login
- **WHEN** a WoW Forever character logs in and the client gives no realm name
- **THEN** its stock is still recorded, under its ruleset

#### Scenario: Same first name, different surnames
- **WHEN** two WoW Forever characters on the same ruleset and faction share a first name
- **THEN** each has its own stock record and its own line in the stock details

#### Scenario: Classic Era unchanged
- **WHEN** a Classic Era character logs in
- **THEN** its stock is filed under the same realm and name as before, and saved stock is left exactly as it was
