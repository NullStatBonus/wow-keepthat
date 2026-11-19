# settings Specification

## Purpose

Defines KeepThat's settings pages, their defaults, the per-material review, and the slash and debug commands, so the player controls what is marked and how.

## Requirements

### Requirement: Settings pages
The addon SHALL register KeepThat under Options > AddOns with Home, Materials, Integrations, Appearance, Advanced and About, in that order, using AceConfig. `/kt` and `/kt settings` SHALL open Home. Appearance SHALL own category colors, icon tint strength, toast opacity/scale, toast sound and channel, and positioning; Home SHALL retain what to mark and where to show it. Existing controls SHALL remain reachable with the same values.

#### Scenario: Open settings
- **WHEN** the player types `/kt` or `/kt settings`
- **THEN** KeepThat opens on Home and Appearance is reachable

#### Scenario: Appearance relocation
- **WHEN** the player opens Appearance after upgrading
- **THEN** existing configured category colors and opacity remain and are editable

### Requirement: Defaults
A new install SHALL default to: endgame materials on, leveling materials off, tooltip line on, loot toast off, toast sound Auction open, toast sound channel Master, login reminder on, icon mask off, endgame color purple, leveling color green, and "Show marks in" with bags, bank and merchant checked.

#### Scenario: First login
- **WHEN** the addon loads with no saved settings
- **THEN** every setting has the default listed above

#### Scenario: Upgrade
- **WHEN** a player with saved settings from an earlier version loads this version
- **THEN** the toast sound is Auction open, the channel is Master, and every earlier setting keeps its saved value

### Requirement: Settings apply without reload
Every change on Home, Materials, Integrations and Appearance, and every corresponding slash setter, SHALL take effect immediately or on the next normal tooltip, toast or bag refresh without reload. Profile changes SHALL refresh all dependent presentation state.

#### Scenario: Turn on leveling materials
- **WHEN** leveling materials are enabled and the player hovers a leveling material
- **THEN** the tooltip shows its Leveling line without reload

#### Scenario: CLI presentation change
- **WHEN** a valid appearance setter is used
- **THEN** the settings page and owned visible samples reflect the same value without reload

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
The player SHALL move, lock or reset the loot-toast anchor from Appearance using the transactional Move workflow in visual-preview. Done SHALL save the position, Cancel or Escape SHALL restore the starting position, and right-click MAY remain a Done alias. Later toasts SHALL stack below the first. Reset position SHALL affect only the anchor.

#### Scenario: Move the toasts
- **WHEN** Move is chosen on Appearance, the placeholder is dragged and Done is chosen
- **THEN** later toasts appear at the saved position, stacked below it

#### Scenario: Cancel move
- **WHEN** the placeholder is dragged then Escape is pressed
- **THEN** the original position returns and no tentative position is saved

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
Each material page SHALL keep its "Your stock" section. It SHALL give the realm-and-faction total split between this character and the player's other characters, then one line per character holding any: this character first, then the others by count, each other character with the grey age of its oldest counted source. Every holder SHALL be listed, and the page SHALL NOT ask the player to open a bank or mailbox.

#### Scenario: Stock across characters
- **WHEN** a route still needs 40 Runecloth, this character has 12 in bags and 8 in the bank, Bankmule has 30 in the bank, Hunter has 5 in the mailbox, and every bank and mailbox is counted
- **THEN** the page shows `55 owned - 20 on this character, 35 on your other characters`, a line for each of the three characters, and "You have enough."

#### Scenario: Nobody holds it
- **WHEN** no character in scope holds the material
- **THEN** the section says the player has none, with no per-character lines

### Requirement: Still to get across characters
A leveling page SHALL show how many are still to get: the count still needed minus the realm-and-faction total, as a range when the guides differ, or that the player has enough. While the total is incomplete, the still-to-get line SHALL be hidden. An endgame page SHALL show what each leveling route still needs of the item when it is also a leveling material.

#### Scenario: Leveling material with some in the bank
- **WHEN** a route still needs 40 Linen Cloth, the player has 10 in bags and 15 in the bank, no other character holds any, and every bank and mailbox is counted
- **THEN** the page shows `This character: 10 in bags, 15 in the bank` and "Still to get: 15"

#### Scenario: Enough on hand
- **WHEN** the total is at least the top of the range and every bank and mailbox is counted
- **THEN** the page says "You have enough."

#### Scenario: Incomplete total
- **WHEN** a route still needs 40 Linen Cloth and another character's mailbox has not been counted
- **THEN** the still-to-get line is hidden and no note explains why

### Requirement: Sample visuals on demand
`/kt demo` SHALL retain three sample loot toasts (endgame, leveling and both) at the toast position and a native tooltip at the mouse for a random real material with realistic sample profession skills and bag counts, whatever the real feature settings are, and SHALL include an isolated tint sample. It SHALL follow visual-preview safety and restoration rules. `/kt preview <kind>` SHALL target one surface; existing `/kt test toast`, `tooltip` and `copy` SHALL remain supported.

#### Scenario: One explicit test
- **WHEN** `/kt test toast`, `/kt test tooltip` or `/kt test copy` is used
- **THEN** only that element appears; `/kt test` without a kind lists kinds

#### Scenario: Toasts turned off
- **WHEN** loot toasts are off and `/kt demo` is run
- **THEN** three sample toasts appear and fade without enabling real toasts or consuming session deduplication

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
The Materials page SHALL have a session-only search input that filters materials and professions by literal, case-insensitive client or English item names, reports no matches, and can be cleared from the Materials page or any profession page. `/kt find <name>` SHALL open a single matching path, open Materials filtered to the query for several, report none, or say which Home checkbox shows a hidden match.

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
- **WHEN** several paths match `/kt find <name>`, for example Arcanite Bar under Blacksmithing and Engineering
- **THEN** the KeepThat window opens on Materials with the search set to the name, only the professions with a match are expanded, and nothing is listed in chat

#### Scenario: Find only hidden materials
- **WHEN** several paths match `/kt find <name>` and the Home checkboxes hide all of them
- **THEN** chat says which Home checkbox shows them, and settings do not open

#### Scenario: Find no material
- **WHEN** no paths match `/kt find <name>`
- **THEN** chat reports that no material matches

#### Scenario: Find without a name
- **WHEN** the player types `/kt find` without a name
- **THEN** chat shows usage

### Requirement: Materials launcher in the game's Settings window
In the game's Settings window, the Materials entry under KeepThat SHALL be a short launcher page with an explanation and an "Open KeepThat" button, not the Materials tree. The button SHALL close the game's Settings window and open the standalone KeepThat window on Materials. The other five KeepThat entries SHALL show their full pages there.

#### Scenario: Materials from the game's Settings window
- **WHEN** the player opens Options > AddOns > KeepThat > Materials
- **THEN** the page explains that materials are reviewed in the KeepThat window and offers "Open KeepThat", and no material tree is shown there

#### Scenario: Open KeepThat from the launcher
- **WHEN** the player clicks "Open KeepThat" on that page
- **THEN** the game's Settings window closes and the standalone KeepThat window opens on Materials

#### Scenario: Leaving the launcher is instant
- **WHEN** the player moves from the Materials entry to another KeepThat entry in the game's Settings window
- **THEN** the other page opens without a noticeable pause

### Requirement: Materials professions start collapsed
Every profession under Materials SHALL start collapsed each time the KeepThat window opens, whatever was expanded earlier in the session. Opening a specific material (for example from `/kt find`) SHALL expand only the path to that material.

#### Scenario: Professions start collapsed
- **WHEN** the player expands Blacksmithing and Tailoring, closes the settings and opens them again
- **THEN** Materials lists every profession collapsed

#### Scenario: Find opens one profession
- **WHEN** the player uses `/kt find` on a name that matches one material under one profession
- **THEN** only that profession is expanded, with the material selected

### Requirement: AddOns list icon
Both TOC files SHALL name the same KeepThat icon with `## IconTexture:`, and the named file SHALL ship inside the addon folder as a square, power-of-two TGA with an alpha channel.

#### Scenario: Icon in the AddOns list
- **WHEN** the player opens the game's AddOns list on Classic Era or WoW Forever
- **THEN** KeepThat shows its badge icon next to its name

### Requirement: Login reminder setting
Home SHALL have a "Login reminder" checkbox under "Where to show it", after "Loot toast" and before "Icon tint". Its hover text SHALL be "Remind you at login when a character's bank or mailbox is not counted." It SHALL control the character-stock login reminder and SHALL be the same setting as `/kt set stock.reminder`. The "displays are off" note on Home SHALL NOT consider it.

#### Scenario: Turn the reminder off
- **WHEN** the player clears "Login reminder" on Home
- **THEN** `/kt get stock.reminder` returns `off` and no reminder prints at the next login

### Requirement: Toast sound picker
Appearance > Loot toast SHALL offer a Sound picker listing None, then Auction open, Level up, Quest complete, Ready check, Raid warning, PvP queue ready, Murloc aggro, Bell toll (Alliance), Bell toll (Horde) and Battle.net toast, then any sounds registered with LibSharedMedia-3.0, labeled as sound packs, when another addon provides that library. Choosing a sound SHALL play it once. The picker SHALL work without LibSharedMedia.

#### Scenario: No library
- **WHEN** no installed addon provides LibSharedMedia-3.0 and the player opens the Sound picker
- **THEN** it lists None and the ten built-in sounds, and no error appears

#### Scenario: Sound packs present
- **WHEN** another addon registers a sound named "Air Horn" with LibSharedMedia-3.0
- **THEN** the picker also lists "Air Horn (sound pack)" after the built-in sounds

#### Scenario: Audition
- **WHEN** the player chooses Level up in the picker
- **THEN** the level-up sound plays once and Level up is saved

#### Scenario: Saved pack missing
- **WHEN** the saved sound is a sound pack that is no longer installed and the player opens the picker
- **THEN** the picker shows the default, Auction open, as the sound that will play, and the saved choice is not overwritten until the player picks again

### Requirement: Toast sound channel
Appearance > Loot toast SHALL offer a Sound channel picker with Master and Sound effects. Master SHALL play even when the game's sound effects are turned off.

#### Scenario: Sound effects off
- **WHEN** the channel is Master, the game's sound effects are off, and a new toast appears
- **THEN** the toast sound is heard

#### Scenario: Sound effects channel
- **WHEN** the player chooses Sound effects and turns off the game's sound effects
- **THEN** new toasts are silent
