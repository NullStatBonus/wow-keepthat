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

### Requirement: Recipe status on endgame recipe lines
While Shift is held, each endgame recipe line of a profession the character has SHALL end with a grey status in parentheses: `(Learned · <Difficulty>)`, `(Not learned · <Difficulty>)`, `(Not learned)` or `(<Difficulty>)`. The difficulty word (Orange, Yellow, Green, Gray) SHALL be drawn in its difficulty color and SHALL match the profession window's color at the current rank. A part that is unknown SHALL be left out. With both parts unknown, the line SHALL have no status.

#### Scenario: Learned and still raising skill
- **WHEN** the character knows Transmute: Arcanite at Alchemy 280, and it turns yellow at 275 and gray at 290
- **THEN** its line ends with `(Learned · Yellow)`, "Yellow" in yellow

#### Scenario: Learned but gray
- **WHEN** the character knows an endgame recipe whose gray rank is at or below the current rank
- **THEN** its line ends with `(Learned · Gray)`, and the material's purpose and recipe quantity still show

#### Scenario: Learned, difficulty unknown
- **WHEN** the character knows a recipe whose catalog entry has no thresholds
- **THEN** its line ends with `(Learned)`

#### Scenario: Not learned
- **WHEN** the complete record says the character does not know Arcanite Reaper, and the current rank is below its yellow rank
- **THEN** its line ends with `(Not learned)`

#### Scenario: Not learned, rank at or above yellow
- **WHEN** the complete record says the character does not know a recipe, and the current rank is above its gray rank
- **THEN** its line ends with `(Not learned · Gray)`

#### Scenario: Not learned, rank below yellow
- **WHEN** the character does not know a recipe and the current rank is below its yellow rank
- **THEN** the line shows `(Not learned)` with no difficulty word, because the addon cannot tell orange from "too low to learn"

#### Scenario: Knowledge unknown, rank below yellow
- **WHEN** the character's Alchemy knowledge is unknown and the current rank is below a recipe's yellow rank
- **THEN** that line shows no status, because "Orange" would also cover a recipe the character cannot learn yet

#### Scenario: Profession the character does not have
- **WHEN** the character has no Blacksmithing and holds Shift over Arcanite Bar
- **THEN** the Blacksmithing recipe lines show no status

### Requirement: Recipe lines follow the chosen order
The endgame recipe lines of a profession SHALL follow the "Recipe order" setting. With Learned first (the default), the order SHALL be learned, then unknown, then not learned. With Not learned first, it SHALL be not learned, then unknown, then learned. With Highest skill first, learned status SHALL be ignored. Within each group, the order SHALL be by yellow rank, highest first, then spell ID. Recipes with no thresholds come last. The three-line limit does not change.

#### Scenario: Learned recipe no longer hidden
- **WHEN** a material is used by five Tailoring recipes and the character knows only the one with the lowest yellow rank
- **THEN** that recipe is the first line shown, and `and 2 more recipes` follows the third line

#### Scenario: Not learned first
- **WHEN** "Recipe order" is Not learned first and the character knows two of five Tailoring recipes that use the material
- **THEN** the three lines shown are recipes marked `(Not learned)`

#### Scenario: Highest skill first
- **WHEN** "Recipe order" is Highest skill first
- **THEN** the lines are ordered by yellow rank, highest first, whatever is learned

#### Scenario: Knowledge unknown
- **WHEN** the character's Tailoring knowledge is unknown
- **THEN** the lines are ordered by yellow rank, highest first, in every order setting

### Requirement: Hint when recipe knowledge is unknown
When the character has a profession whose recipes the addon can record on this client, but its recipe knowledge is unknown, that profession's endgame block SHALL end with one grey line telling the player to open that profession to see which recipes they know, after any `and N more recipes` line. The hint SHALL go away once the knowledge is recorded.

#### Scenario: Window never opened
- **WHEN** the character has Alchemy, has never opened it, and holds Shift over Arcane Crystal
- **THEN** the Alchemy block shows one line `Open Alchemy to see which recipes you know`, and the recipe lines show only their difficulty where the rank is at or above yellow

#### Scenario: After opening the window
- **WHEN** the player opens Alchemy, closes it, and holds Shift over Arcane Crystal again
- **THEN** the hint is gone and the recipe lines show learned or not learned

### Requirement: Recipe status follows changes
The recipe status SHALL update the next time the tooltip is drawn after the character learns a recipe or a profession rank changes.

#### Scenario: Rank-up turns a recipe green
- **WHEN** Alchemy rises from 281 to 282 and Transmute: Arcanite turns green at 282
- **THEN** the next Shift tooltip shows `(Learned · Green)` for it

#### Scenario: Recipe learned
- **WHEN** the player learns Arcanite Reaper from a trainer
- **THEN** the next Shift tooltip shows `(Learned · <Difficulty>)` for it, or the difficulty alone if knowledge became unknown
