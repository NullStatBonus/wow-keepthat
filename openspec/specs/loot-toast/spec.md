# loot-toast Specification

## Purpose

Defines the optional short pop-up shown when the player loots a marked material, and how repeated pickups are combined so it never becomes spam.

## Requirements

### Requirement: Toast off by default
The loot toast SHALL be off by default and SHALL appear only when the player has turned it on.

#### Scenario: Default settings
- **WHEN** settings are default and the player loots Arcanite Bar
- **THEN** no toast appears

### Requirement: Toast on looting a marked item
When enabled and a marked item is received by looting, the addon SHALL show an informational toast using the local visual contract: baseline 280 by 40 units, a 28-unit icon, neutral item name/count and secondary text with only the category word colored, plus a subtle category accent when background opacity is nonzero. Both categories SHALL be named when applicable. Long localized content SHALL grow rather than clip. The recommendation meaning SHALL match the tooltip; the whole line need not share one color. The toast SHALL fade in over about 0.3 seconds and fade out gradually over the last 1.5 seconds of its 4-second life, without input.

#### Scenario: Loot a marked item
- **WHEN** enabled toasts receive one looted Arcanite Bar
- **THEN** the icon, neutral Arcanite Bar x1 title and Endgame category in its configured color appear with Blacksmithing, then fade

#### Scenario: Gradual fade
- **WHEN** a toast has shown for 3.25 seconds
- **THEN** it is half transparent, and it is fully gone at 4 seconds

#### Scenario: Loot an unmarked item
- **WHEN** an unmarked item is looted
- **THEN** no toast appears

#### Scenario: Not a loot
- **WHEN** a marked item arrives by purchase, mail, trade or crafting
- **THEN** no toast appears

#### Scenario: Long subtitle
- **WHEN** the localized subtitle does not fit baseline geometry
- **THEN** the toast expands without hiding its category or recommendation

### Requirement: One toast per item per session
Each item SHALL produce at most one toast per game session. Later pickups of the same item while its toast is showing SHALL add to its count; pickups after it faded SHALL show nothing.

#### Scenario: Second pickup while showing
- **WHEN** the player loots 2 Thorium Ore while the Thorium Ore toast still shows `x3`
- **THEN** the same toast shows `x5` and no second toast appears

#### Scenario: Pickup after fading
- **WHEN** the Thorium Ore toast has faded and the player loots more Thorium Ore in the same session
- **THEN** no toast appears

#### Scenario: New session
- **WHEN** the player logs in again or reloads the UI and loots Thorium Ore
- **THEN** a toast appears again

### Requirement: Toasts stay out of the way
Toasts SHALL not take mouse input away from the game world, SHALL stack when several show at once, and SHALL show at most three at a time. The newest toast SHALL show at the saved position and older toasts SHALL sit above it. When toasts change place they SHALL glide there rather than jump, and a toast leaving SHALL not move the others.

#### Scenario: Many items at once
- **WHEN** the player loots five different marked items at once
- **THEN** at most three toasts show, and the others show as earlier ones fade

#### Scenario: Newer toast arrives
- **WHEN** a toast is showing and the player loots a different marked item
- **THEN** the new toast appears at the saved position and the earlier toast glides up above it

#### Scenario: Oldest toast fades
- **WHEN** three toasts show and the top one fades away
- **THEN** the other two stay where they are

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
