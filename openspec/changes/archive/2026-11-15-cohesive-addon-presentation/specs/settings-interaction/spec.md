## ADDED Requirements

### Requirement: Settings landmarks
The addon SHALL expose Home, Materials, Integrations, Appearance, Advanced and About in that order with its existing renderer. Home SHALL emphasize feature choices, Appearance SHALL own visuals/positioning, Advanced SHALL show diagnostics/scope, and About SHALL show version/purpose/commands. Existing feature controls SHALL remain reachable.

#### Scenario: Common landmarks
- **WHEN** the settings UI opens
- **THEN** Home, Appearance, Advanced and About are reachable alongside feature-specific pages

#### Scenario: Feature retention
- **WHEN** a player uses an existing feature page after upgrading
- **THEN** its settings remain reachable and retain their gameplay effect



#### Scenario: Existing renderer and domain content
- **WHEN** settings are reorganized
- **THEN** AceConfig remains; Materials retains search/stock/recipes/export/copy behavior and Integrations retains optional detection and Classic Era limits

### Requirement: Settings scope and immediate parity
The window title SHALL remain KeepThat; page content SHALL explain the active Shared settings or This character scope. Persistence defaults SHALL remain unchanged. UI and slash setters SHALL share validation and refresh behavior, applying without reload on the next normal refresh at latest. Scope switches SHALL explain their effect before applying, retain both profiles and never silently copy or reset data.

#### Scenario: UI and CLI agree
- **WHEN** a public setting is changed by slash command while its page is open
- **THEN** the effective value and page agree and live visuals refresh without reload

#### Scenario: Two characters
- **WHEN** a setting changes on one character
- **THEN** the existing account/profile or character scoping rules are preserved after relog

#### Scenario: Scope switch
- **WHEN** a player selects a different supported profile scope
- **THEN** the effect is explained and switching back restores prior profile values


### Requirement: Consistent control vocabulary
Applicable controls SHALL use Background opacity, Text and icon opacity, Scale, Preview, Move, Lock position, Reset position, Record debug information and Show debug report. Dependent controls SHALL retain their values while disabled and explain the enabling prerequisite. Unsupported features SHALL NOT gain inert controls. Irreversible data-clearing UI actions SHALL require explicit confirmation; changing appearance SHALL NOT clear gameplay data.

#### Scenario: Disabled dependency
- **WHEN** a feature is off and its appearance controls are shown
- **THEN** the saved values remain visible with an explanation and cannot be accidentally overwritten

#### Scenario: Reset scope
- **WHEN** Reset position is used
- **THEN** only position resets and colors, scale, opacity, thresholds and profile data remain unchanged

### Requirement: Context before settings choices
Each settings page SHALL explain its purpose and next action. Scope SHALL appear in Advanced and where it changes a choice. Guidance SHALL explain control effects. Dynamic guidance SHALL match feature and Move state. Preview actions SHALL name their surface. Integration rows SHALL explain their function and availability.

#### Scenario: Direct page entry
- **WHEN** a player opens a settings page directly
- **THEN** its purpose and relevant next action are visible; scope appears on Advanced and where it changes a choice without visiting another page or hovering a control

#### Scenario: Context follows state
- **WHEN** a feature, scope or Move state changes
- **THEN** guidance and dependent controls reflect the new state, retaining saved values and explaining how to continue
