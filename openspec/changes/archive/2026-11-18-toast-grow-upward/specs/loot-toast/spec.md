# Spec Delta

## MODIFIED Requirements

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
