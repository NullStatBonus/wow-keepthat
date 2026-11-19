# Spec Delta

## ADDED Requirements

### Requirement: Toast sound
When the loot toast is on and a newly looted marked item is accepted for a toast (shown now or waiting its turn), the addon SHALL play the chosen toast sound once on the chosen channel at that moment. Adding to an existing toast's count SHALL be silent. With the loot toast off, no sound SHALL play. The default SHALL be the game's auction house opening sound on the Master channel.

#### Scenario: First pickup
- **WHEN** toasts are on with default settings and the player loots Thorium Ore for the first time this session
- **THEN** the Thorium Ore toast appears and the auction house opening sound plays once on the Master channel

#### Scenario: Count added
- **WHEN** the Thorium Ore toast is showing and the player loots 2 more Thorium Ore
- **THEN** the toast count rises and no sound plays

#### Scenario: Toast off
- **WHEN** the loot toast is off and the player loots Arcanite Bar
- **THEN** no toast appears and no sound plays

### Requirement: No bundled sound files
KeepThat SHALL play only sounds the game client or another installed addon already provides, and SHALL ship no sound files.

#### Scenario: Fresh install
- **WHEN** the addon is installed with no other addons
- **THEN** every built-in sound choice plays from the game client's own data

### Requirement: One sound per loot burst
After the toast sound plays, further new toasts accepted within 2 seconds SHALL be silent, so looting several marked items at once plays one sound, including toasts that wait and appear later.

#### Scenario: Five items at once
- **WHEN** toasts are on and the player loots five different marked items within a second
- **THEN** the sound plays once, and no sound plays when the fourth and fifth toasts appear later

#### Scenario: After the cooldown
- **WHEN** a toast sound played and the player loots a different marked item ten seconds later
- **THEN** the sound plays again

### Requirement: No sound
Choosing None SHALL keep the toast and play nothing.

#### Scenario: None chosen
- **WHEN** the toast sound is None and the player loots a new marked item
- **THEN** the toast appears and no sound plays

### Requirement: Unavailable sound falls back
When the chosen sound cannot be played on this client (for example a sound pack whose addon was removed, or a game sound the client lacks), the addon SHALL play the default sound instead, keep the player's saved choice unchanged, and raise no Lua error. If the default also cannot play, the toast SHALL still appear silently.

#### Scenario: Sound pack removed
- **WHEN** the saved toast sound came from a sound pack that is no longer installed and a new toast appears
- **THEN** the auction house opening sound plays, no error appears, and the saved choice is unchanged

#### Scenario: No sound function
- **WHEN** the client provides no way to play sounds and a new toast appears
- **THEN** the toast appears without sound and no error appears

### Requirement: Samples play the sound
Toast samples (Preview loot toast, `/kt test toast`, `/kt demo`) SHALL play the chosen sound once per request, whether or not the loot toast is on and regardless of the cooldown, and SHALL not start the cooldown for real loot.

#### Scenario: Preview while off
- **WHEN** the loot toast is off, the toast sound is Murloc aggro, and the player selects Preview loot toast
- **THEN** one sample toast shows and the murloc sound plays once

#### Scenario: Demo
- **WHEN** the player types `/kt demo`
- **THEN** three sample toasts show and the chosen sound plays once
