## MODIFIED Requirements

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
