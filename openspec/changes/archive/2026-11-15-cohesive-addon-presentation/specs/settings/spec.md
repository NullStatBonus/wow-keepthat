## MODIFIED Requirements

### Requirement: Settings pages
The addon SHALL register KeepThat under Options > AddOns with Home, Materials, Integrations, Appearance, Advanced and About, in that order, using AceConfig. `/kt` and `/kt settings` SHALL open Home. Appearance SHALL own category colors, icon tint strength, toast opacity/scale and positioning; Home SHALL retain what to mark and where to show it. Existing controls SHALL remain reachable with the same values.

#### Scenario: Open settings
- **WHEN** the player types `/kt` or `/kt settings`
- **THEN** KeepThat opens on Home and Appearance is reachable

#### Scenario: Appearance relocation
- **WHEN** the player opens Appearance after upgrading
- **THEN** existing configured category colors and opacity remain and are editable


### Requirement: Settings apply without reload
Every change on Home, Materials, Integrations and Appearance, and every corresponding slash setter, SHALL take effect immediately or on the next normal tooltip, toast or bag refresh without reload. Profile changes SHALL refresh all dependent presentation state.

#### Scenario: Turn on leveling materials
- **WHEN** leveling materials are enabled and the player hovers a leveling material
- **THEN** the tooltip shows its Leveling line without reload

#### Scenario: CLI presentation change
- **WHEN** a valid appearance setter is used
- **THEN** the settings page and owned visible samples reflect the same value without reload


### Requirement: Loot toast position
The player SHALL move, lock or reset the loot-toast anchor from Appearance using the transactional Move workflow in visual-preview. Done SHALL save the position, Cancel or Escape SHALL restore the starting position, and right-click MAY remain a Done alias. Later toasts SHALL stack below the first. Reset position SHALL affect only the anchor.

#### Scenario: Move the toasts
- **WHEN** Move is chosen on Appearance, the placeholder is dragged and Done is chosen
- **THEN** later toasts appear at the saved position, stacked below it

#### Scenario: Cancel move
- **WHEN** the placeholder is dragged then Escape is pressed
- **THEN** the original position returns and no tentative position is saved


### Requirement: Sample visuals on demand
`/kt demo` SHALL retain three sample loot toasts (endgame, leveling and both) at the toast position and a native tooltip at the mouse for a random real material with realistic sample profession skills and bag counts, whatever the real feature settings are, and SHALL include an isolated tint sample. It SHALL follow visual-preview safety and restoration rules. `/kt preview <kind>` SHALL target one surface; existing `/kt test toast`, `tooltip` and `copy` SHALL remain supported.

#### Scenario: One explicit test
- **WHEN** `/kt test toast`, `/kt test tooltip` or `/kt test copy` is used
- **THEN** only that element appears; `/kt test` without a kind lists kinds

#### Scenario: Toasts turned off
- **WHEN** loot toasts are off and `/kt demo` is run
- **THEN** three sample toasts appear and fade without enabling real toasts or consuming session deduplication
