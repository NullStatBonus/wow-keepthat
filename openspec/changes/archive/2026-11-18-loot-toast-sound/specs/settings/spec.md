# Spec Delta

## MODIFIED Requirements

### Requirement: Settings pages
The addon SHALL register KeepThat under Options > AddOns with Home, Materials, Integrations, Appearance, Advanced and About, in that order, using AceConfig. `/kt` and `/kt settings` SHALL open Home. Appearance SHALL own category colors, icon tint strength, toast opacity/scale, toast sound and channel, and positioning; Home SHALL retain what to mark and where to show it. Existing controls SHALL remain reachable with the same values.

#### Scenario: Open settings
- **WHEN** the player types `/kt` or `/kt settings`
- **THEN** KeepThat opens on Home and Appearance is reachable

#### Scenario: Appearance relocation
- **WHEN** the player opens Appearance after upgrading
- **THEN** existing configured category colors and opacity remain and are editable

### Requirement: Defaults
A new install SHALL default to: endgame materials on, leveling materials off, tooltip line on, loot toast off, toast sound Auction open, toast sound channel Master, login reminder on, icon mask off, endgame color purple, leveling color green, and "Show marks in" with bags, bank and merchant checked.

#### Scenario: First login
- **WHEN** the addon loads with no saved settings
- **THEN** every setting has the default listed above

#### Scenario: Upgrade
- **WHEN** a player with saved settings from an earlier version loads this version
- **THEN** the toast sound is Auction open, the channel is Master, and every earlier setting keeps its saved value

## ADDED Requirements

### Requirement: Toast sound picker
Appearance > Loot toast SHALL offer a Sound picker listing None, then Auction open, Level up, Quest complete, Ready check, Raid warning, PvP queue ready, Murloc aggro, Bell toll (Alliance), Bell toll (Horde) and Battle.net toast, then any sounds registered with LibSharedMedia-3.0, labeled as sound packs, when another addon provides that library. Choosing a sound SHALL play it once. The picker SHALL work without LibSharedMedia.

#### Scenario: No library
- **WHEN** no installed addon provides LibSharedMedia-3.0 and the player opens the Sound picker
- **THEN** it lists None and the ten built-in sounds, and no error appears

#### Scenario: Sound packs present
- **WHEN** another addon registers a sound named "Air Horn" with LibSharedMedia-3.0
- **THEN** the picker also lists "Air Horn (sound pack)" after the built-in sounds

#### Scenario: Audition
- **WHEN** the player chooses Level up in the picker
- **THEN** the level-up sound plays once and Level up is saved

#### Scenario: Saved pack missing
- **WHEN** the saved sound is a sound pack that is no longer installed and the player opens the picker
- **THEN** the picker shows the default, Auction open, as the sound that will play, and the saved choice is not overwritten until the player picks again

### Requirement: Toast sound channel
Appearance > Loot toast SHALL offer a Sound channel picker with Master and Sound effects. Master SHALL play even when the game's sound effects are turned off.

#### Scenario: Sound effects off
- **WHEN** the channel is Master, the game's sound effects are off, and a new toast appears
- **THEN** the toast sound is heard

#### Scenario: Sound effects channel
- **WHEN** the player chooses Sound effects and turns off the game's sound effects
- **THEN** new toasts are silent
