# Spec Delta

## ADDED Requirements

### Requirement: Character profile follows the new character name
When the settings library names a character differently than before (WoW Forever), a per-character profile saved under the earlier name SHALL be moved to the new name once at load, keeping its values and whether the character uses it, but only when no profile exists under the new name. Turning "This character" off and on afterwards SHALL return the same settings. An existing profile under the new name SHALL never be overwritten.

#### Scenario: Character using its own profile
- **WHEN** a WoW Forever character uses its own profile saved under the earlier name and logs in
- **THEN** it uses a profile under its new name with the same values, and the earlier-named profile is gone

#### Scenario: Toggle off and on keeps the settings
- **WHEN** that character turns "This character" off and then on again
- **THEN** it gets its own settings back, not defaults

#### Scenario: Character on the shared settings
- **WHEN** a WoW Forever character is on the shared settings and a profile saved under its earlier name exists
- **THEN** it stays on the shared settings, and turning "This character" on brings back that profile's values

#### Scenario: Profile under the new name already exists
- **WHEN** profiles exist under both the earlier and the new name
- **THEN** both are left unchanged and the character keeps the profile it was using

#### Scenario: Classic Era
- **WHEN** a Classic Era character logs in
- **THEN** its profiles and profile choice are unchanged
