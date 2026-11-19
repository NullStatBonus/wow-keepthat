# Spec Delta

## MODIFIED Requirements

### Requirement: Settings saved per account with profiles
Settings SHALL be saved for the whole account by default, with the option to use a per-character profile. A character's profile choice SHALL survive a change in how the settings library names characters (WoW Forever drops the realm and adds the surname): the choice saved under the earlier name SHALL apply once, and SHALL NOT replace a choice already made under the new name.

#### Scenario: Second character
- **WHEN** the player logs into another character on the same account with default profile settings
- **THEN** that character uses the same KeepThat settings

#### Scenario: Forever character keeps its own profile after the library update
- **WHEN** a WoW Forever character that used its own profile under the earlier character name logs in with a library that uses the new name
- **THEN** that character still uses its own profile with the same values, and the other characters still use the shared settings

#### Scenario: Restored only once
- **WHEN** that character has been restored, then the player switches it to the shared settings and logs in again
- **THEN** it stays on the shared settings

#### Scenario: Choice under the new name is kept
- **WHEN** the character already has its own profile chosen under the new name and an earlier choice under the old name
- **THEN** the choice under the new name stays

#### Scenario: Classic Era unchanged
- **WHEN** a Classic Era character logs in and the character name did not change
- **THEN** its profile choice and all saved settings are left exactly as they were
