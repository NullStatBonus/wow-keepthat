## ADDED Requirements

### Requirement: Broad synthetic demo
`/kt demo` SHALL show clearly identified representative synthetic visuals even when real visuals are disabled, preserving existing sample coverage. Demo SHALL NOT buy, navigate, call production acceptance callbacks, change saved/gameplay data or consume real deduplication/cooldowns. Repeating SHALL replace samples and restart the lifetime; ending SHALL restore current live state and existing navigation.

#### Scenario: No side effects
- **WHEN** any demo button is accepted or clicked
- **THEN** no purchase, waypoint, learned data, ledger or saved-setting change occurs

#### Scenario: Repeat and restore
- **WHEN** demo is run again before ending while real data changes
- **THEN** samples replace prior samples and ending restores current live state rather than a stale snapshot

#### Scenario: Disabled feature
- **WHEN** the feature is disabled and demo is run
- **THEN** samples appear without changing its enabled state or real-event cooldown/deduplication



#### Scenario: Representative coverage
- **WHEN** demo runs
- **THEN** three toasts covering endgame/leveling/both, a mouse-position sample tooltip and an isolated tint appear; normal toast fade timing applies and auxiliary samples close or expire predictably

### Requirement: Focused visual previews
`/kt preview` SHALL list supported kinds: toast, tooltip, tint, copy. `preview <kind>` and an Appearance Preview action SHALL show one isolated synthetic visual using current appearance. Previewing an alternative presentation SHALL NOT save that choice. Unavailable class-specific kinds SHALL explain why they cannot be shown. Existing test commands SHALL retain their integration-test semantics, separate from safe previews.

#### Scenario: Compare a style
- **WHEN** a different style is previewed
- **THEN** only the sample changes and the saved notification choice is unchanged

#### Scenario: Unknown kind
- **WHEN** an unsupported preview kind is supplied
- **THEN** valid kinds are listed and no gameplay action occurs


### Requirement: Transactional Move mode
Appearance SHALL offer clamped placeholder Move mode with visible Done and Cancel. Move SHALL snapshot the start, commit only on Done and restore on Cancel/Escape. Lock position SHALL block all movement until explicitly unlocked. Reset position SHALL change only position. Positions SHALL use existing profile/character scope.

#### Scenario: Done
- **WHEN** a placeholder is moved and Done is chosen
- **THEN** the clamped position is saved and later visuals use it

#### Scenario: Cancel or Escape
- **WHEN** a placeholder is moved and Cancel or Escape is used
- **THEN** the starting position returns and persisted position is unchanged

#### Scenario: Locked
- **WHEN** the position is locked and Move or drag is attempted
- **THEN** the position does not change and the UI explains how to unlock

#### Scenario: Profile change while moving
- **WHEN** the active scope changes during Move mode
- **THEN** the old move is cancelled without writing its tentative position into either scope

#### Scenario: Move targets
- **WHEN** Move is chosen
- **THEN** the player can move the loot-toast anchor; right-click may remain a Done alias

#### Scenario: Normal input
- **WHEN** Move mode is not active
- **THEN** real toasts remain mouse-transparent


### Requirement: Realistic item tooltip preview
Tooltip previews SHALL select a random real material from the active catalog and routes, populate native item content when available and draw KeepThat recommendations through the same renderer as a live hover. Sample profession skills and bag counts SHALL be clearly identified and isolated from saved settings, live classification and optional integration callbacks.

#### Scenario: Match a real hover
- **WHEN** a tooltip preview is opened and Shift is held or released
- **THEN** native item content and KeepThat category, detail and recipe rows use the live layout and semantic colors with realistic sample counts

#### Scenario: Uncached sample item
- **WHEN** the randomly selected material is not cached
- **THEN** its catalog name appears safely and native item content replaces the fallback when item data arrives without changing the selected sample
