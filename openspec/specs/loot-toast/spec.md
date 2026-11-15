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
When enabled and a marked item is received by looting, the addon SHALL show an informational toast using the local visual contract: baseline 280 by 40 units, a 28-unit icon, neutral item name/count and secondary text with only the category word colored, plus a subtle category accent when background opacity is nonzero. Both categories SHALL be named when applicable. Long localized content SHALL grow rather than clip. The recommendation meaning SHALL match the tooltip; the whole line need not share one color. The toast SHALL fade after a few seconds without input.

#### Scenario: Loot a marked item
- **WHEN** enabled toasts receive one looted Arcanite Bar
- **THEN** the icon, neutral Arcanite Bar x1 title and Endgame category in its configured color appear with Blacksmithing, then fade

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
Toasts SHALL not take mouse input away from the game world, SHALL stack when several show at once, and SHALL show at most three at a time.

#### Scenario: Many items at once
- **WHEN** the player loots five different marked items at once
- **THEN** at most three toasts show, and the others show as earlier ones fade
