# Spec Delta

## ADDED Requirements

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
