# Tasks

Each check is marked **unit** (`make test`) or **in-game**. Only the in-game ones go on the release checklist (3 for this release).

## 1. Stock identity

- [x] 1.1 `Core/Adapter_Stock.lua` `PlayerIdentity`: realm from `GetNormalizedRealmName` (D1), name "Name Surname" plus the surname as a 4th return in surname mode (D2). **Unit**, in `tests/test_adapter_stock.lua`:
  - Forever stub (`UnitFullName` -> "Me","Smith", `RegionalUniqueNamesEnabled` true, `UnitNameUnmodified` -> "Me","Smith", `GetNormalizedRealmName` -> "Realm") gives "Me Smith","Realm",faction,"Smith".
  - Era stubs keep "Ann","Realm".
  - Verify the new tests fail against the old code.
- [x] 1.2 `Model/Stock.lua` `Stock.Move` (D3). **Unit**, in `tests/test_stock.lua`:
  - The record moves with its sources and times.
  - It is not moved when the target exists.
  - Emptied buckets are removed.
  - A non-table source is ignored.
- [x] 1.3 `Core/Stock.lua` calls `Stock.Move` at `PLAYER_LOGIN` in surname mode. **Unit**, in `tests/test_stock_recorder.lua`:
  - A save with `realms.Smith.Alliance.Me` logs in as "Me Smith" on "Realm" and finds its bank counted.
  - A second alt "Bo Jones" sees Me Smith in `R.Total`.
  - The Era identity leaves the save deep-equal.
- [x] 1.4 Docs:
  - `docs/contracts.md`: Forever `UnitFullName` return (source, not measured by us) and the stock identity rule; update the "KeepThat uses" line with `GetNormalizedRealmName`, `RegionalUniqueNamesEnabled`, `UnitNameUnmodified`.
  - `README.md` "Good to know": on Forever, each alt's stock is shared again after that alt logs in once.
  - Verify with `make check` and `tests/test_readme.lua`.

## 2. Profile rename guard

- [x] 2.1 `Model/ProfileKey.lua` `Rename`: return false when another `profileKeys` entry names `oldKey` (D4). **Unit**, in `tests/test_profilekey.lua`:
  - The review's repro: Smith migrates under 0.4.3, Jones logs in first under 0.4.4, then Smith keeps toastScale 1.5 and Jones stays on Default.
  - Existing rename tests still pass.
  - Verify the new test fails against the old code.

## 3. Release checks

- [x] 3.1 `docs/test-plan.md`: add "## 11. Forever character names". Setup: a Forever save used with 0.4.4 or earlier, two alts on one realm and faction with different surnames, the bank of alt A counted before. Three **in-game** checks:
  1. Log in alt A: `/kt status stock` names the realm, not the surname.
  2. Log in alt B: the Shift stock block on a material in A's bank shows "A-name A-surname: N".
  3. On alt A, turn "This character" on, change the toast scale, relog: the scale is kept.
  - Verify the section numbers stay unique and in order.
- [x] 3.2 `make test` and `make check` pass.
- [ ] 3.3 In-game checks 11.1–11.3 reported by the player. (Not reported before archive; commit and PR were requested first.)

## Workflow follow-up

- Archive at `/opsx:archive`: sync specs, bump both TOCs to 0.4.5, add the CHANGELOG line.
- Merge, tag and publish only when asked.
