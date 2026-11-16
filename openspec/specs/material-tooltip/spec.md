# material-tooltip Specification

## Purpose

Defines the short tooltip line that marks endgame and leveling materials, and the details that appear while Shift is held. This line is the addon's main feature.

## Requirements

### Requirement: One short line per marked item
When the tooltip line is enabled (the default), the tooltip of a marked item SHALL gain exactly one line: `KeepThat: Endgame: <Profession>` or `KeepThat: Leveling: <Profession>`. "KeepThat:" SHALL be grey, only the category word SHALL be in its category color, and the profession names SHALL be neutral. While Shift is not held, the line SHALL end with a grey `(Shift)` hint. Unmarked items SHALL gain no line.

#### Scenario: Endgame item
- **WHEN** the player hovers Arcanite Bar with default settings and owns none on any character in scope
- **THEN** the tooltip shows one line `KeepThat: Endgame: Blacksmithing (Shift)`, with "Endgame" in purple

#### Scenario: Unmarked item
- **WHEN** the player hovers an item that is not marked
- **THEN** the tooltip gains no line from the addon

#### Scenario: Tooltip line off
- **WHEN** the tooltip line setting is off
- **THEN** no tooltip gains a line from the addon

### Requirement: Owned total on the line
When the realm-and-faction total of the item is more than 0, the line SHALL add ` - <N> owned` after the professions and before the `(Shift)` hint, with the dash grey and the count neutral. At 0 it SHALL add nothing.

#### Scenario: Owned across characters
- **WHEN** the player hovers Runecloth and the realm-and-faction total is 55
- **THEN** the line reads `KeepThat: Leveling: Tailoring - 55 owned (Shift)`

### Requirement: Several professions or both categories
An item used by more than one profession SHALL list them in the same line, at most two by name followed by `+N`. An item marked in both categories SHALL read `KeepThat: Endgame + Leveling: <Professions>`, each category word in its own color.

#### Scenario: Two professions
- **WHEN** an endgame material is used by Alchemy and Blacksmithing
- **THEN** the line reads `KeepThat: Endgame: Alchemy, Blacksmithing`

#### Scenario: Many professions
- **WHEN** an endgame material is used by four professions
- **THEN** the line names two of them and ends with `+2`

#### Scenario: Both categories
- **WHEN** Thorium Bar is marked endgame and leveling for Blacksmithing
- **THEN** the line reads `KeepThat: Endgame + Leveling: Blacksmithing`, "Endgame" in purple and "Leveling" in green

### Requirement: Details while Shift is held
While Shift is held, the tooltip SHALL add below the line one block per category and profession: a heading in the category color (`Endgame - Blacksmithing`, `Leveling - Tailoring, skill 260-300`), then indented neutral lines (the purpose; the count still needed and how many the current character carries in bags), then indented grey notes (recipes with their quantity per craft, the share for an intermediate, the guides).

#### Scenario: Shift on an endgame item
- **WHEN** the player holds Shift over Arcanite Bar
- **THEN** the tooltip lists the endgame recipes that use it with quantities

#### Scenario: Shift on a leveling item
- **WHEN** the player holds Shift over a leveling material with a known count
- **THEN** the tooltip shows `Leveling - Tailoring, skill 260-280` and under it `40 needed, 12 in bags`, or `40-55 needed, 12 in bags` when the guides differ

#### Scenario: Shift on a material used to make another
- **WHEN** the player holds Shift over Thorium Ore, which is marked because it makes Thorium Bar for Arcanite Bar
- **THEN** the details say it is used to make Thorium Bar for Arcanite Bar

#### Scenario: Shift released
- **WHEN** the player releases Shift
- **THEN** the tooltip returns to the single line, with its `(Shift)` hint

### Requirement: Stock block while Shift is held
While Shift is held and any character in scope holds the item, the details SHALL end with a grey `Stock` heading and one neutral line per holder (`This character: 20`, `Bankmule: 30`): the current character first, then by count, highest first, then by name. At most 5 lines SHALL show, then `+N more`.

#### Scenario: Stock across characters
- **WHEN** the player holds Shift over Runecloth, with 20 on this character, 30 on Bankmule and 5 on Hunter
- **THEN** a `Stock` block lists `This character: 20`, `Bankmule: 30`, `Hunter: 5` in that order

#### Scenario: More than five holders
- **WHEN** eight characters in scope hold the item
- **THEN** the Stock block shows five character lines and `+3 more`

### Requirement: Works wherever item tooltips appear
The line SHALL appear on item tooltips in bags, bank, merchant, auction house, loot, mail, trade, chat item links, and recipe reagents, and SHALL appear only once per tooltip.

#### Scenario: Chat link
- **WHEN** the player clicks a chat link for a marked item
- **THEN** the item tooltip shows the line once
