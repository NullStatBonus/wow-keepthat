# Spec Delta

## MODIFIED Requirements

### Requirement: Defaults
A new install SHALL default to: endgame materials on, leveling materials off, tooltip line on, loot toast off, toast sound Auction open, toast sound channel Master, login reminder on, recipe order Learned first, icon mask off, endgame color purple, leveling color green, and "Show marks in" with bags, bank and merchant checked.

#### Scenario: First login
- **WHEN** the addon loads with no saved settings
- **THEN** every setting has the default listed above

#### Scenario: Upgrade
- **WHEN** a player with saved settings from an earlier version loads this version
- **THEN** the toast sound is Auction open, the channel is Master, the recipe order is Learned first, and every earlier setting keeps its saved value

## ADDED Requirements

### Requirement: Recipe order setting
Home SHALL show a "Recipe order" choice under "Tooltip line", with Learned first, Not learned first, and Highest skill first. It SHALL be disabled while the tooltip line is off, and it SHALL keep its saved value. A change SHALL show on the next Shift tooltip without a reload.

#### Scenario: Change the order
- **WHEN** the player picks Not learned first and holds Shift over Runecloth
- **THEN** the Tailoring recipe lines list not-learned recipes first

#### Scenario: Tooltip line off
- **WHEN** the tooltip line is off
- **THEN** "Recipe order" is shown but disabled, and its value stays the same
