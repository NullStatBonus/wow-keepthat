## ADDED Requirements

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
- **WHEN** the player uses `/kt find` to open Arcanite Bar
- **THEN** only the profession it is opened under is expanded, with Arcanite Bar selected
