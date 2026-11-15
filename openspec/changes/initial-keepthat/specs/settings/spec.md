# Spec Delta

## Purpose

Defines KeepThat's settings pages, their defaults, the per-material review, and the slash and debug commands, so the player controls what is marked and how.

## ADDED Requirements

### Requirement: Settings pages
The addon SHALL register its settings under Options > AddOns as **KeepThat**, with the pages Home, Materials, Integrations, Advanced and About. The slash command `/kt` SHALL open them.

#### Scenario: Open settings
- **WHEN** the player types `/kt`
- **THEN** the KeepThat settings open on the Home page

### Requirement: Defaults
A new install SHALL default to: endgame materials on, leveling materials off, tooltip line on, loot toast off, icon mask off, endgame color purple, leveling color green, and "Show marks in" with bags, bank and merchant checked.

#### Scenario: First login
- **WHEN** the addon loads with no saved settings
- **THEN** every setting has the default listed above

### Requirement: Settings apply without reload
Every change on Home and Materials SHALL take effect on the next tooltip, toast or bag refresh, without a UI reload.

#### Scenario: Turn on leveling materials
- **WHEN** the player turns on leveling materials and hovers a leveling material
- **THEN** the tooltip shows the `Leveling:` line without a reload

### Requirement: Materials review
One Materials page SHALL show a tree of profession, then material, each material once per profession. The list SHALL follow the Home checkboxes (only the enabled categories, or all when neither is). Each tree entry SHALL show a small swatch per category in the tint colors before its neutral name. A material page SHALL show the icon and the name in the item's quality color, a keep toggle per category it is in, its uses, counts, recipes, stock and one Wowhead copy button, and no data source.

#### Scenario: Review a material in both categories
- **WHEN** the player opens Materials > Blacksmithing > Thorium Bar, an endgame and leveling material
- **THEN** the page shows its icon, its name in its quality color, "Keep for endgame" and "Keep for leveling", one Used for line per category, How many, the recipes, Your stock and one Copy Wowhead link button

#### Scenario: Copy a link
- **WHEN** the player clicks the item's Wowhead button
- **THEN** a box opens with the item's Wowhead link selected, ready to copy with Ctrl+C

#### Scenario: The list follows Home
- **WHEN** leveling materials are off and endgame materials are on
- **THEN** leveling-only materials and professions left empty are not listed

#### Scenario: Nothing marked
- **WHEN** both categories are off on Home
- **THEN** every material is listed with a note that none are marked

#### Scenario: Export per category
- **WHEN** the player opens a profession page with both endgame and leveling materials
- **THEN** it offers "Export endgame list" and "Export leveling list"

### Requirement: Loot toast position
The player SHALL be able to move the loot toasts from the Home page: a button shows a placeholder toast to drag, and a second button resets the position. The position SHALL be saved with the other settings, and later toasts SHALL stack below the first.

#### Scenario: Move the toasts
- **WHEN** the player clicks Move loot toasts, drags the placeholder and right-clicks it
- **THEN** the next loot toasts appear at the new place, stacked below it

### Requirement: Material toggles survive catalog updates
Toggles the player changed SHALL be kept across addon updates. Materials newly added to the catalog SHALL start on.

#### Scenario: Update adds a material
- **WHEN** an addon update adds a new endgame material and the player had turned off another one
- **THEN** the new material is on and the one the player turned off stays off

### Requirement: Integrations page
The Integrations page SHALL list Baganator, Bagnon, EllesmereUI Bags, Auctionator and DFL Profession Journal, show for each whether it is detected and working, and give each a toggle, on by default.

#### Scenario: Addon not installed
- **WHEN** Bagnon is not installed
- **THEN** its row says it is not detected and its toggle has no effect

### Requirement: Integrations on WoW Forever only in this version
On Classic Era, the addon SHALL not run any integration with another addon. The Integrations page SHALL say that integrations are not yet available on Classic Era. All other features SHALL work on Classic Era.

#### Scenario: Bag addon on Classic Era
- **WHEN** Baganator is installed on Classic Era and the icon mask is on
- **THEN** Baganator shows no overlay, Blizzard's own bags do, and the Integrations page says integrations are not yet available on Classic Era

### Requirement: Material stock on its page
Each material page SHALL show how many the player has in bags and in the bank (as far as the client knows it). A leveling page SHALL also show how many are still to get: the count still needed minus what the player has, as a range when the guides differ, or that the player has enough. An endgame page SHALL show what each leveling route still needs of the item when it is also a leveling material.

#### Scenario: Leveling material with some in the bank
- **WHEN** a route still needs 40 Linen Cloth and the player has 10 in bags and 15 in the bank
- **THEN** the page shows "10 in bags, 15 in the bank" and "Still to get: 15"

#### Scenario: Enough on hand
- **WHEN** the player has at least the top of the range
- **THEN** the page says "You have enough."

### Requirement: Sample visuals on demand
`/kt demo` SHALL show three sample loot toasts (endgame, leveling, both) at the toast position and a sample item tooltip at the mouse, whatever the toast and tooltip settings are, so the look can be checked at any time.

#### Scenario: One explicit test
- **WHEN** the player types `/kt test toast`, `/kt test tooltip` or `/kt test copy`
- **THEN** only that element is shown; `/kt test` with no type lists the types

#### Scenario: Toasts turned off
- **WHEN** loot toasts are off and the player types `/kt demo`
- **THEN** three sample toasts appear and fade like real ones

### Requirement: Debug report
`/kt debug on` SHALL start recording diagnostics and `/kt log` SHALL show a copyable report that lists every setting, the detected integrations and their state, and recorded failures.

#### Scenario: Report after an integration failure
- **WHEN** an integration was disabled after a failure and the player types `/kt log`
- **THEN** the report names that integration and the reason it was disabled

### Requirement: Settings saved per account with profiles
Settings SHALL be saved for the whole account by default, with the option to use a per-character profile.

#### Scenario: Second character
- **WHEN** the player logs into another character on the same account with default profile settings
- **THEN** that character uses the same KeepThat settings

### Requirement: Material search
The Materials page SHALL have a session-only search input that filters materials and professions by literal, case-insensitive client or English item names, reports no matches, and can be cleared from the Materials page or any profession page. `/kt find <name>` SHALL open a single matching path, list up to ten paths for several, report none, or say which Home checkbox shows a hidden match.

#### Scenario: Filter materials
- **WHEN** the player enters part of an item name and presses Enter on the Materials page
- **THEN** only matching materials and nonempty professions remain, or a neutral no-match sentence appears

#### Scenario: Clear a search
- **WHEN** the player clicks Clear search on the Materials page or a profession page
- **THEN** all materials return

#### Scenario: Find one material path
- **WHEN** the player types `/kt find <name>` and exactly one path matches
- **THEN** settings open on that material page

#### Scenario: Find several material paths
- **WHEN** several paths match `/kt find <name>`
- **THEN** chat lists up to ten paths sorted by item name with category and profession, plus the remaining count, and settings do not open

#### Scenario: Find no material
- **WHEN** no paths match `/kt find <name>`
- **THEN** chat reports that no material matches

#### Scenario: Find without a name
- **WHEN** the player types `/kt find` without a name
- **THEN** chat shows usage
