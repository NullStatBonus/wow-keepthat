## MODIFIED Requirements

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

### Requirement: Materials professions start collapsed
Every profession under Materials SHALL start collapsed each time the KeepThat window opens, whatever was expanded earlier in the session. Opening a specific material (for example from `/kt find`) SHALL expand only the path to that material.

#### Scenario: Professions start collapsed
- **WHEN** the player expands Blacksmithing and Tailoring, closes the settings and opens them again
- **THEN** Materials lists every profession collapsed

#### Scenario: Find opens one profession
- **WHEN** the player uses `/kt find` on a name that matches one material under one profession
- **THEN** only that profession is expanded, with the material selected
