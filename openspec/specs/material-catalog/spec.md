# material-catalog Specification

## Purpose

Defines which items KeepThat treats as endgame or leveling materials, the facts it ships about each one, and how an item is classified under the player's current settings.

## Requirements

### Requirement: Shipped material catalog
The addon SHALL ship a catalog of materials for every crafting profession. Each entry SHALL name the item, its profession or professions, its category (endgame, leveling, or both), and the recipes that use it.

#### Scenario: Endgame entry carries its recipes
- **WHEN** the catalog entry for Arcanite Bar is read
- **THEN** it is marked endgame for Blacksmithing and lists the endgame recipes that use it with the quantity each needs

#### Scenario: Item in both categories
- **WHEN** an item is used both by endgame recipes and on a profession's leveling route (for example Thorium Bar)
- **THEN** its entry carries both categories and the details for each

### Requirement: Endgame scope
An item SHALL be an endgame material only if it is used by a recipe for a raid or dungeon consumable, for best-in-slot crafted gear for any class, or for another craft that the cited expert guides call essential at level 60.

#### Scenario: Low-level reagent not endgame
- **WHEN** an item is used only by recipes below skill 200 that make no endgame consumable or gear
- **THEN** it is not an endgame material

#### Scenario: Gathered material used by an endgame recipe
- **WHEN** a gathered item (for example Black Lotus) is a reagent of an endgame recipe
- **THEN** it is an endgame material for the profession of that recipe

### Requirement: Materials made from other materials
When an endgame material is made by a recipe, the materials of that recipe SHALL also be endgame materials for the same profession, recursively, each recording the material it is used to make. A material SHALL NOT be expanded when no recipe makes it, when more than one recipe makes it, or when its recipe only converts one element or essence into another (for example "Transmute: Air to Fire").

#### Scenario: Arcanite Bar
- **WHEN** Arcanite Bar is an endgame Blacksmithing material and only Transmute: Arcanite makes it
- **THEN** Arcane Crystal and Thorium Bar are endgame Blacksmithing materials, each recorded as used to make Arcanite Bar

#### Scenario: Two levels down
- **WHEN** Thorium Bar is added because of Arcanite Bar, and only smelting makes Thorium Bar from Thorium Ore
- **THEN** Thorium Ore is an endgame Blacksmithing material recorded as used to make Thorium Bar

#### Scenario: Element conversion not expanded
- **WHEN** Essence of Fire is an endgame material and the only recipe that makes it is Transmute: Air to Fire
- **THEN** Essence of Air is not added because of Essence of Fire

### Requirement: Every entry cites its source
Each catalog entry SHALL record the source it was drawn from, and the repository SHALL credit every source in its third-party notices.

#### Scenario: Source recorded
- **WHEN** any catalog entry is inspected
- **THEN** it names at least one source, and that source is credited in the third-party notices

### Requirement: Classification follows settings
An item SHALL be classified as endgame, leveling, both, or unmarked. A category counts only when it is enabled and the player has not turned off that material on its settings page.

#### Scenario: Leveling off by default
- **WHEN** settings are default and the player hovers an item that is only a leveling material
- **THEN** the item is unmarked

#### Scenario: Material turned off
- **WHEN** the player turns off Arcanite Bar on its settings page
- **THEN** Arcanite Bar is unmarked, while the other endgame materials stay marked

#### Scenario: Unknown item
- **WHEN** an item is not in the catalog
- **THEN** it is unmarked and no error occurs

### Requirement: A catalog for each client
The addon SHALL ship a separate catalog for Classic Era and for WoW Forever, each built from that client's own recipe data, and SHALL use the catalog of the running client.

#### Scenario: Recipe moved to another profession on Forever
- **WHEN** a recipe belongs to Alchemy on Classic Era and to First Aid on WoW Forever
- **THEN** its materials are marked for Alchemy on Classic Era and for First Aid on WoW Forever

#### Scenario: Recipe only on one client
- **WHEN** a recipe exists only on WoW Forever
- **THEN** on Classic Era its materials are not marked because of that recipe

### Requirement: Recipe difficulty thresholds
Each recipe in the shipped catalog SHALL carry the skill rank at which it turns yellow and the rank at which it turns gray, from that client's own game data. A recipe whose game data gives no usable thresholds SHALL carry none, and its difficulty SHALL be unknown.

#### Scenario: Thresholds from game data
- **WHEN** Classic Era's game data says Transmute: Arcanite turns yellow at 275 and gray at 290
- **THEN** the Classic Era catalog carries 275 and 290 for that recipe

#### Scenario: Thresholds differ per client
- **WHEN** a recipe turns gray at a different rank on WoW Forever than on Classic Era
- **THEN** each client's catalog carries its own rank

#### Scenario: No usable thresholds
- **WHEN** a recipe's game data has no gray rank, or a gray rank below its yellow rank
- **THEN** the catalog carries no thresholds for it
