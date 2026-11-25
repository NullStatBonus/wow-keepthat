# Spec Delta

## MODIFIED Requirements

### Requirement: Integrations on WoW Forever only in this version
On Classic Era, the addon SHALL not run any integration with another addon, except the CheckThat integration, which carries test evidence only and runs on both clients. The Integrations page SHALL say that integrations are not yet available on Classic Era. All other features SHALL work on Classic Era.

#### Scenario: Bag addon on Classic Era
- **WHEN** Baganator is installed on Classic Era and the icon mask is on
- **THEN** Baganator shows no overlay, Blizzard's own bags do, and the Integrations page says integrations are not yet available on Classic Era

#### Scenario: CheckThat on Classic Era
- **WHEN** CheckThat is installed on Classic Era
- **THEN** the CheckThat integration runs, and the Integrations page still says integrations are not yet available on Classic Era

### Requirement: Debug report
`/kt debug on` SHALL start recording diagnostics and `/kt log` SHALL show a copyable report that lists every setting, the detected integrations and their state, and recorded failures.

#### Scenario: Report after an integration failure
- **WHEN** an integration was disabled after a failure and the player types `/kt log`
- **THEN** the report names that integration and the reason it was disabled

#### Scenario: Report with CheckThat loaded
- **WHEN** CheckThat is loaded and the player types `/kt log`
- **THEN** the report lists the CheckThat integration and its state with the other integrations
