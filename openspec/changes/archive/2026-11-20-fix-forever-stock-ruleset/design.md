# Design

## Context

Measured from the player's Forever saved variables (2026-11-20):
- **Our log:** "no player identity" in every session since 0.4.5.
- **Syndicator's records:** `["Banksy …-PvE"]` with `realmNormalized = "PvE"`.
- **The settings library:** AceDB-3.0 minor 40 keys realms by `C_GameRules.IsGameRuleActive(Enum.GameRule.*Ruleset)` when `RegionalUniqueNamesEnabled()` is true.

## Decisions

- **D1. Ruleset as the realm in surname mode, decided as AceDB does it.**
  - The check order is Hardcore, then RP plus PvP ("RP-PvP"), then RP, then PvP, else "PvE".
  - It reads `C_GameRules.IsGameRuleActive` through the adapter's guarded `try`.
  - Without `C_GameRules` or `Enum.GameRule`, it falls back to the realm name, as 0.4.5 did.
  - *Alternative:* the realm name first and the ruleset as fallback. Rejected: if the realm name were sometimes empty and sometimes set, a character's stock would split across two keys.
- **D2. Keep the move from 0.4.5 unchanged.** It already moves `realms[surname][faction][first]` to `realms[realm][faction]["first surname"]`. Only the target realm changes.
- **D3. Test with the real save.** An anonymized fixture runs through the recorder:
  - character A logs in and its surname bucket moves to "PvE" under its full name;
  - character C logs in and counts A's bank;
  - B, who hasn't logged in yet, stays where it was.

## Risks / Trade-offs

- **[The ruleset spans more players than a realm did]** → That only affects which of your own characters are pooled. Stock is per account, so nothing else changes. This is the same scope Syndicator and Baganator show.
