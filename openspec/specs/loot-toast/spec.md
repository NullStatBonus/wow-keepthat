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
When the toast is on and the player receives a marked item by looting, the addon SHALL show a toast with the item icon, name and count, and the same line the tooltip uses, in the same color. The toast SHALL fade after a few seconds without input.

#### Scenario: Loot a marked item
- **WHEN** the toast is on and the player loots one Arcanite Bar
- **THEN** a toast shows the Arcanite Bar icon, `Arcanite Bar x1` and `Endgame: Blacksmithing` in purple, then fades

#### Scenario: Loot an unmarked item
- **WHEN** the player loots an item that is not marked
- **THEN** no toast appears

#### Scenario: Not a loot
- **WHEN** a marked item arrives by purchase, mail, trade or crafting
- **THEN** no toast appears

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
Toasts SHALL not take mouse input away from the game world, SHALL stack when several show at once, and SHALL show at most three at a time.

#### Scenario: Many items at once
- **WHEN** the player loots five different marked items at once
- **THEN** at most three toasts show, and the others show as earlier ones fade
