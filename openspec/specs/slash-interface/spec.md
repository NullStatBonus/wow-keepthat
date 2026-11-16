# slash-interface Specification

## Purpose
Defines the `/kt` commands: settings pages, help and status topics, the allowlisted get/set settings registry, previews, the demo, and the debug log.

## Requirements

### Requirement: Common command discovery
The addon SHALL provide `/kt settings [page]`, `status [topic]`, `help [topic]`, `demo`, `preview [kind]`, `get <key>`, `set <key> <value>`, `debug on|off`, `log` and `log clear`. Status topics SHALL include `stock`, which lists each character in scope with a bank or mailbox not counted, and what is missing. Existing valid commands and bare-command behavior SHALL remain, except demo side effects explicitly superseded by visual-preview. Help, About and README SHALL document demo.

#### Scenario: Legacy entry point
- **WHEN** `/kt` or an existing valid domain command is used
- **THEN** its existing behavior remains available

#### Scenario: Grouped help
- **WHEN** `/kt help appearance` is used
- **THEN** targeted examples, valid keys and preview kinds are shown instead of a monolithic command line

#### Scenario: Report clearing
- **WHEN** `/kt log clear` is requested then cancelled
- **THEN** no diagnostic entries or gameplay data are cleared

#### Scenario: Explicit pages
- **WHEN** settings is used with no page or a case-insensitive page slug
- **THEN** no page opens Home; valid slugs match settings-interaction; invalid pages list valid choices without writes

#### Scenario: Topic help and status
- **WHEN** help or status is requested
- **THEN** help groups appearance, diagnostics and domain topics and rejects unknown topics with valid choices; status reports scope, effective values and feature availability

#### Scenario: Stock status
- **WHEN** `/kt status stock` is used while Bankmule's mailbox and Hunter's bank are not counted
- **THEN** chat names the realm and faction and the number of characters counted, then shows `Bankmule: mailbox not counted.` and `Hunter: bank not counted.`

#### Scenario: Log purpose
- **WHEN** log or log clear is used
- **THEN** log opens a copyable report; new log clear confirms irreversible diagnostic-only clearing and never clears gameplay data

### Requirement: Allowlisted setting registry
Public keys SHALL be stable identifiers independent of SavedVariables paths. Entries SHALL declare type, enum/bounds, scope, getter, setter and refresh callback. UI and CLI SHALL share validation and effects. Arbitrary Lua paths or executable input SHALL be rejected. Get SHALL be read-only; invalid, missing or surplus input SHALL not write. New setters SHALL give one concise acknowledgement; valid legacy commands SHALL remain compatible.

#### Scenario: Invalid mutation
- **WHEN** an unknown key, invalid enum, fractional integer, out-of-range number or trailing argument is supplied
- **THEN** no value changes and the reply states valid syntax and values

#### Scenario: Single acknowledgement
- **WHEN** one new setter succeeds
- **THEN** one concise acknowledgement names the effective value

#### Scenario: Preserve names
- **WHEN** an existing find or named-item command receives mixed-case text
- **THEN** only command words are normalized and name/search behavior remains intact

#### Scenario: Parsing names
- **WHEN** a name/search command contains mixed-case text
- **THEN** only command words and enums are normalized; user-entered names/search text are preserved

#### Scenario: Targeted validation
- **WHEN** invalid input is rejected
- **THEN** the reply gives exact syntax and allowed values/bounds and no setting changes

### Requirement: Initial public settings
The initial public registry SHALL provide the keys, types, bounds, defaults and scopes in the Public key registry scenario. Existing saved values SHALL override new-install defaults. Existing numeric limits SHALL come from the shared command limits rather than copied constants. Additional keys SHALL be documented with validation and scenarios.

#### Scenario: Read and write the primary key
- **WHEN** `/kt set toast on` is followed by get for that key
- **THEN** get returns the same effective value and existing UI reflects it

#### Scenario: Public key registry
- **WHEN** a supported public key is read or written
- **THEN** the following registry applies; old stored alpha is migrated without changing effective brightness:

| Key | Type / bounds | New-install default | Scope |
| --- | --- | --- | --- |
| toast | boolean on/off | off | active profile |
| tooltip | boolean on/off | on | active profile |
| stock.reminder | boolean on/off | on | active profile |
| appearance.toast.background-opacity | integer 0–100 | 100 on new installs; migrate old alpha | active profile |
| appearance.toast.text-opacity | integer 0–100 | 100 on new installs; migrate old alpha | active profile |
| appearance.toast.scale | integer 50–200 | 100 | active profile |
| appearance.toast.locked | boolean on/off | off | active profile |

#### Scenario: Reminder key
- **WHEN** `/kt set stock.reminder off` is used
- **THEN** the Home "Login reminder" checkbox is cleared and no reminder prints at the next login
