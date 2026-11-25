# checkthat-integration Specification

## Purpose

Lets CheckThat, the in-game test runner, prove KeepThat's results from facts, entry calls and debug lines, while KeepThat works the same for players with CheckThat missing, old or idle.

## Requirements

### Requirement: Works without CheckThat
KeepThat SHALL behave the same for the player whether CheckThat is missing, is an older version without the calls KeepThat uses, or is loaded with no test run open. No Lua error SHALL reach the player in any of these cases.

#### Scenario: CheckThat not installed
- **WHEN** the player plays with KeepThat and no CheckThat
- **THEN** every KeepThat feature works as before and no Lua error appears

#### Scenario: CheckThat without entry points
- **WHEN** a CheckThat version without `CheckThat.Entry` is loaded
- **THEN** KeepThat registers no entries, reports facts only if `CheckThat.Report` exists, and no Lua error appears

#### Scenario: No run open
- **WHEN** CheckThat is loaded, no run is open, and KeepThat reports a fact that CheckThat declines
- **THEN** KeepThat treats the declined fact as normal, keeps the integration on, and records no failure

### Requirement: CheckThat failure is contained
If a call into CheckThat raises an error, KeepThat SHALL turn the CheckThat integration off for the session, make no further CheckThat calls, and name the integration and the reason in the debug report. An error inside a KeepThat entry SHALL be recorded as a failure in the debug report and SHALL NOT reach CheckThat as a raised error. All other features SHALL keep working.

#### Scenario: Report raises an error
- **WHEN** `CheckThat.Report` raises an error during play
- **THEN** no Lua error reaches the player, later results report no facts, and `/kt log` lists the CheckThat integration as failed with the reason

#### Scenario: Entry raises an error
- **WHEN** a plan calls a KeepThat entry whose code raises an error
- **THEN** the result starts with `error:`, and `/kt log` lists the failure with the entry name

### Requirement: CheckThat support on both clients without a setting
The CheckThat integration SHALL run on WoW Forever and on Classic Era whenever CheckThat is loaded. It SHALL have no setting and no row on the Integrations page, and the debug report SHALL list its state with the other integrations.

#### Scenario: Classic Era with CheckThat
- **WHEN** CheckThat is loaded on Classic Era and the player types `/kt log`
- **THEN** the report lists the CheckThat integration as detected and working, and the Integrations page shows no CheckThat row

### Requirement: Version entry
KeepThat SHALL offer a `version` entry that returns its version as one number, major times 10000 plus minor times 100 plus patch. When the version is not known it SHALL return nothing, never 0.

#### Scenario: Version 0.7.0
- **WHEN** CheckThat calls the `version` entry on KeepThat 0.7.0
- **THEN** the result is the fact `[KeepThat] entry.version=700`

#### Scenario: Version unknown
- **WHEN** the client cannot tell KeepThat its version and CheckThat calls the `version` entry
- **THEN** the result is `(none)`, not a number

### Requirement: Entries registered at login
KeepThat SHALL register its entries when the player logs in, never while its files load, and only through `CheckThat.Entry`. Each entry SHALL be a function with no side effects that returns text, numbers or booleans, at most 120 characters each, and never a character name.

#### Scenario: CheckThat loads after KeepThat
- **WHEN** KeepThat loads before CheckThat and the player logs in
- **THEN** every KeepThat entry is registered once CheckThat is loaded, and a plan step can call it

#### Scenario: Entry changes nothing
- **WHEN** a plan calls any KeepThat entry
- **THEN** no setting, saved stock, recipe record or display changes

### Requirement: Entries for plan checks
KeepThat SHALL offer entries for: an item's classification, the count of a leveling material still needed, a profession's export (item count and list name), a public setting's value, an integration's state, and whether this character's bank and mailbox are counted. An unknown answer SHALL be nothing, never 0 or false.

#### Scenario: Classification of an endgame material
- **WHEN** a plan calls the classification entry for Arcanite Bar on a character with default settings
- **THEN** the result names the endgame category and Blacksmithing

#### Scenario: Setting value
- **WHEN** a plan calls the setting entry with a key that `/kt get` accepts
- **THEN** the result is the same value `/kt get` shows for that key

#### Scenario: Stock counted for this character
- **WHEN** the player opened the bank and the mailbox this session and a plan calls the stock entry
- **THEN** the result is true, and no character name is in the result

### Requirement: Facts reported where the result is decided
KeepThat SHALL report a fact once for each result, at the point where the code decides it, never in a loop or a per-frame handler. Numeric results SHALL be reported as numbers. A result a plan counts SHALL carry a value that changes with each report.

#### Scenario: Leveling export
- **WHEN** the player exports a profession's leveling materials to Auctionator during a run
- **THEN** CheckThat records one `export.items` fact with the number of items in the list

#### Scenario: Toast counter
- **WHEN** two marked items show toasts during a run
- **THEN** CheckThat records two `toast.seq` facts with different values

### Requirement: Debug lines for plan checks
While debug recording is on, each behavior the test plan checks SHALL write one debug line at its decision point with the values that prove it. Refusals and skips SHALL write a line, failures SHALL start with `FAILED:`, a toggle SHALL write a line in both directions, and no line SHALL contain a character name or chat text.

#### Scenario: Toast shown and skipped
- **WHEN** a marked item is looted twice in one session with the loot toast on
- **THEN** the log has one line that the toast for that item ID showed and one line that the second toast was skipped

#### Scenario: Settings window opened
- **WHEN** the player types `/kt`
- **THEN** the log has one line naming the page the window opened on

#### Scenario: Estimate setting toggled
- **WHEN** the player turns "Estimate leveling cost" off and then on
- **THEN** the log has one line for each direction, and the next estimate shown writes its estimate line again

#### Scenario: Repeated tooltip refresh
- **WHEN** the player keeps the mouse over a marked item while its tooltip refreshes many times
- **THEN** the log has at most one line for that item on that tooltip path in the session

### Requirement: Plan checks the version first
The first step of the test plan SHALL check, without player input, that the KeepThat version under test is at least the version the plan was written for.

#### Scenario: Older KeepThat loaded
- **WHEN** a tester starts the plan with an older KeepThat copy in the game
- **THEN** the first step records fail, and the tester stops before the other steps
