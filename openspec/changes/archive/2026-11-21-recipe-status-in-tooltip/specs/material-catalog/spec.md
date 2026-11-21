# Spec Delta

## ADDED Requirements

### Requirement: Recipe difficulty thresholds
Each recipe in the shipped catalog SHALL carry the skill rank at which it turns yellow and the rank at which it turns gray, from that client's own game data. A recipe whose game data gives no usable thresholds SHALL carry none, and its difficulty SHALL be unknown.

#### Scenario: Thresholds from game data
- **WHEN** Classic Era's game data says Transmute: Arcanite turns yellow at 275 and gray at 290
- **THEN** the Classic Era catalog carries 275 and 290 for that recipe

#### Scenario: Thresholds differ per client
- **WHEN** a recipe turns gray at a different rank on WoW Forever than on Classic Era
- **THEN** each client's catalog carries its own rank

#### Scenario: No usable thresholds
- **WHEN** a recipe's game data has no gray rank, or a gray rank below its yellow rank
- **THEN** the catalog carries no thresholds for it
