# recipe-knowledge Specification

## Purpose

Knows which recipes the current character has learned, and says so only when it has seen evidence. It keeps "not learned" apart from "not known yet" so the tooltip never claims a recipe is missing on a guess.

## Requirements

### Requirement: Three states per recipe
For each recipe of a profession the character has, the addon SHALL report one of three states: learned, not learned, or unknown. It SHALL report "not learned" only when it holds a complete record of that profession's recipes for this character. In every other case a recipe that was not seen SHALL be unknown.

#### Scenario: Profession window never opened
- **WHEN** the character has Alchemy and the addon has no record of its Alchemy recipes
- **THEN** every Alchemy recipe is unknown, never "not learned"

#### Scenario: Complete record
- **WHEN** the addon holds a complete record of the character's Blacksmithing recipes and Arcanite Reaper is not in it
- **THEN** Arcanite Reaper is "not learned"

### Requirement: Knowledge is recorded when the profession window opens
When the player opens or updates a profession window, the addon SHALL record which of its recipes the character knows. A record SHALL count as complete only when no search text, filter or collapsed category hides recipes in that window. An incomplete read SHALL add the recipes it saw as learned and SHALL NOT mark any recipe "not learned".

#### Scenario: Window opened with no filter
- **WHEN** the player opens Tailoring with every category expanded and no filter
- **THEN** the addon holds a complete record of the character's Tailoring recipes

#### Scenario: Window opened with a filter
- **WHEN** the player opens Tailoring with "Have materials" checked
- **THEN** the recipes shown are recorded as learned, and no Tailoring recipe becomes "not learned"

### Requirement: Knowledge is kept per character across sessions
The record SHALL be saved per character, so it survives /reload and logout. It SHALL NOT be shared with other characters.

#### Scenario: After a reload
- **WHEN** the player opened Alchemy, then types /reload
- **THEN** Alchemy recipes keep their learned and not-learned states without opening the window again

#### Scenario: Another character
- **WHEN** a second character with Alchemy logs in and has never opened Alchemy
- **THEN** its Alchemy recipes are unknown

### Requirement: A newly learned recipe is never shown as not learned
After the character learns a recipe, the addon SHALL report that recipe as learned, or the profession as unknown until the window is opened again. It SHALL NOT report the recipe "not learned" from an older record.

#### Scenario: Learned from a trainer with the window closed
- **WHEN** the record says Arcanite Reaper is not learned, and the player then learns it from a trainer without opening Blacksmithing
- **THEN** Arcanite Reaper is learned or unknown, never "not learned"

### Requirement: A dropped profession forgets its recipes
When the character no longer has a profession, its record SHALL be removed.

#### Scenario: Unlearn and relearn
- **WHEN** the character drops Alchemy and later learns it again
- **THEN** Alchemy recipes are unknown until the window is opened

### Requirement: Learned status on WoW Forever only in this version
On Classic Era, the addon SHALL NOT record recipe knowledge in this version, because its profession window reads are not yet verified in game. Every recipe there SHALL be unknown, and no hint to open a profession SHALL show. Difficulty from the catalog SHALL still show.

#### Scenario: Classic Era tooltip
- **WHEN** a Classic Era character with Tailoring opens the Tailoring window and holds Shift over Runecloth
- **THEN** the Tailoring recipe lines show only their difficulty word at or above yellow, with no Learned, no Not learned and no hint

### Requirement: A client API is used only once it is proven
If the client offers a way to ask whether a recipe is known without opening the window, the addon SHALL use it only on a client where a probe has confirmed that it reports learned recipes correctly. Otherwise the window record SHALL be the only source.

#### Scenario: API not confirmed
- **WHEN** a probe has not confirmed the client's spell-known check for recipes
- **THEN** recipe states come only from the window record

### Requirement: Knowledge sources in the debug report
The debug report SHALL list, for each profession the character has, where its knowledge comes from (window record, client API, or none), whether the record is complete, and how many recipes are known.

#### Scenario: Report after opening a profession
- **WHEN** the player opened Alchemy with no filter and runs /kt log
- **THEN** the report shows Alchemy with source "window", complete, and the number of known recipes
