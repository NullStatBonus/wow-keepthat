# Tasks

Each check is marked **unit** (`make test`) or **in-game**. The release checklist is the smoke check plus the 4 in-game checks (test plan section 12).

## 1. Bank tab list (D1)

- [x] 1.1 `Core/Adapter_Stock.lua` `BankIDs`: an entry without an ID falls back to the tab enum, and returns nil when that is also missing. **Unit**, in `test_adapter_stock`:
  - the enum fallback;
  - nil when both are missing;
  - in `test_stock_recorder`, a nil list keeps the saved bank.
  - Verify the tests fail against the old code.

## 2. Late changes after closing (D2)

- [x] 2.1 `Core/Stock.lua`: `closedAt` for the bank and the mailbox; changes inside 10 s drop the affected container or the mail record. **Unit**, in `test_stock_recorder`:
  - withdraw-and-close: 18 taken from the bank into bags holding 2, then a late bank event → bags 20, bank container missing, total 20 and incomplete;
  - mail-take-and-close → counted once, mail missing;
  - an event 11 s later changes nothing;
  - other bank containers keep their counts;
  - a normal close keeps everything counted.
  - Verify the tests fail against the old code.

## 3. Profession Journal materials (D3)

- [x] 3.1 `R.Tracked` rebuilds when the context changes and adds the Profession Journal items while `ctx.extra` is set. **Unit**, in `test_stock_recorder`:
  - a Journal-only item in the bank is recorded after the context changes;
  - it is not recorded when `extra` is unset.
  - Verify the test fails against the old code.

## 4. Messages (D4, D5)

- [x] 4.1 `Options/Options.lua` `stockLine`: show "None counted yet." when the total is 0 and incomplete. **Unit**, in `test_options`: covers both texts.
- [x] 4.2 `Core/Stock.lua` login availability, and the `Core/Slash.lua` status line. **Unit**:
  - in `test_stock_recorder`, a fresh character on a client without bank or mail APIs gets no reminder. Update the existing test that expected one.
  - in `test_slash`, the "this client can read" line.
  - `test_locale` passes.

## 5. Docs and release checks

- [x] 5.1 Docs:
  - `README.md` stock "Good to know": a bank or mailbox closed right after a change counts again on the next visit; Profession Journal materials are counted.
  - `docs/contracts.md`: the tab-ID fallback and the window after closing.
  - `docs/test-plan.md` section "## 12. Stock counts", with 4 **in-game** checks:
    1. Bank: take a stack into bags and press Escape at once. The tooltip total is never higher than you own; `/kt status stock` lists the bank as not counted or counts it right. Then open and close the bank normally: `/kt status stock` counts it.
    2. Mailbox: take an attachment and close at once. Same check, plus a normal open and close that stays counted.
    3. An item nobody holds while some bank or mailbox is not counted: its page says "None counted yet."
    4. Forever, with Profession Journal: a material only its route uses, in the bank. After opening the bank, the tooltip total includes it.
  - Verify with `make check` and `test_readme`.
- [x] 5.2 `make test` and `make check` pass.
- [ ] 5.3 In-game checks 12.1–12.4 reported by the player (the PR body carries them as checkboxes). (Not reported before archive; commit and PR were requested first.)

## Workflow follow-up

- At `/opsx:archive`: sync specs, bump both TOCs to 0.4.6, add the CHANGELOG line.
- The PR body lists checks 12.1–12.4 and the smoke check as checkboxes.
- Merge, tag and publish only when asked.
