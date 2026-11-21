# Tasks

## 1. Ruleset realm

- [x] 1.1 `Core/Adapter_Stock.lua`: ruleset realm in surname mode (D1). **Unit**, in `test_adapter_stock`:
  - the save's case (realm name nil or empty at login) gives "PvE";
  - PvP, RP, RP-PvP and Hardcore;
  - no `C_GameRules`: falls back to the realm name;
  - Era unchanged.
  - Fails against 0.4.5's code.
- [x] 1.2 Recorder test with the real-save fixture (D3). **Unit**, in `test_stock_recorder`.
- [x] 1.3 Docs:
  - `docs/contracts.md`: Forever realm = ruleset, with the evidence.
  - `README.md`: on Forever, "realm" means your ruleset.
  - `docs/test-plan.md`: sections 11 and 12 expect `on PvE`.
  - `make test` and `make check` pass.

## Workflow follow-up

- Archive into 0.4.6, which is unpublished, with no second bump. Add a line to the 0.4.6 CHANGELOG section. Commit to PR #24.
