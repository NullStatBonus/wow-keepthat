# Tasks

## 1. Contracts and adapter

- [x] 1.1 Record in `docs/contracts.md` how Syndicator, BagBrother and DataStore read the bank (Era range; Forever's modern character bank tabs) and the mailbox (functions, events, attachment loop, no handling of more than 50 mails or COD), with file references; verify `make check`.
- [x] 1.2 Add `KeepThat/Core/Adapter_Stock.lua` to both TOCs, after `Adapter_Bags.lua`:
  - `A.PlayerIdentity()` and `A.Clock()`.
  - `A.BagIDs()` and `A.BankIDs()`, following Syndicator: the modern tabs when `Enum.BagIndex.CharacterBankTab_1` and `C_Bank.FetchPurchasedBankTabData` exist, else the classic range.
  - `A.ReadContainers(ids, tracked)`, returning nil when any read fails.
  - `A.ReadInbox(tracked)`, returning nil on failure and the unavailable marker when the mail functions are missing.

  Verify in a new `tests/test_adapter_stock.lua` with fake envs:
  - Era range and Forever tabs.
  - A failed slot gives nil.
  - The attachment itemID falls back to the link.
  - Missing functions give unavailable.
  - Keyring and guild bank IDs are never included.

  Also verify `make check` (TOC order).

## 2. Model

- [x] 2.1 Add `KeepThat/Model/Stock.lua` (both TOCs) with `Scope`, `Prune`, `Source`, `Total`, `Missing` and `Age`, per design D6. Verify in `tests/test_stock.lua`:
  - The total across sources and characters.
  - Other realm and faction excluded.
  - Incomplete when a bank or mail is not counted; unavailable stays complete.
  - A 90-day character is pruned and excluded.
  - A 90-day bank or mail counts as not counted.
  - A backwards clock.
  - Row order: self, then count, then name.
  - Ages with singular and plural buckets.

  Break each rule and confirm a test fails.
- [x] 2.2 Add `profile.stockReminder = true` to `KeepThat/Core/Defaults.lua`. `global.stock` is not an AceDB default, because AceDB's recursive merge would write into another version's data; the recorder creates it at login. Verify in `tests/test_core.lua` by loading the real AceDB-3.0 from `KeepThat/Libs` over a saved table: an existing `global.log` and saved stock survive, a new install gets an empty stock and the reminder on, and an unknown `version` is left untouched (documented in the design).

## 3. Recording

- [x] 3.1 Add a stock recorder (`KeepThat/Core/Stock.lua`, both TOCs, registered with `ns.Start`):
  - Build the tracked IDs from the catalog and routes, independent of settings.
  - At `PLAYER_LOGIN`, set `seen` and prune, then queue every bag for the next frame as Syndicator does. A failed first read leaves the bags not counted, and the next `BAG_UPDATE` retries.
  - Queue bags on `BAG_UPDATE` and `BAG_CONTAINER_UPDATE`, and process the pending set once on the next frame (Syndicator's pattern).
  - Read the bank on open and on changes while open, and stop at close.
  - Read the mailbox with one deferred full rescan per `MAIL_INBOX_UPDATE`.
  - Commit each container whole with its own `t`, and keep that container's old record on failure (logged). Recheck that the window is open when the pending set runs, and drop queued bank or mail work at close.
  - Event payloads per design D4: a modern tab index is mapped to its tab bag; re-enumerate after a bag swap or a tab or bag purchase.
  - Use `ns.Listen` for every event.

  Verify in `tests/test_stock_recorder.lua` with a fake adapter:
  - A deposit changes bags and bank with the total unchanged.
  - Taking mail moves a count from mail to bags.
  - A failed read keeps the record.
  - A guild bank event changes nothing.
  - Open, queue, then close before the next frame: nothing is overwritten.
  - One failed bank bag keeps its old record and age, while the others update.
  - Modern `PLAYERBANKSLOTS_CHANGED(tab)` updates that tab; a tab purchase adds it to the expected set.
  - An empty slot is not a failure, and an occupied slot without ID or count is.
  - A mail with a header but no attachment ID or link keeps the previous mail record.
  - The reagent bag is included where it exists.
  - An unmarked route material is recorded with leveling off.

## 4. Surfaces

- [x] 4.1 Tooltip line: `Wording.ColoredLine` appends `L[" - %d owned"]` (grey dash, neutral count) when owned is more than 0, before `(Shift)`; `UI/Tooltip.lua` passes the total. Verify in `tests/test_wording.lua` and `tests/test_tooltip.lua` (55 owned shown; 0 omitted; the hint stays last).
- [x] 4.2 Shift: keep `"%s needed, %d in bags"`, and add the Stock block (a grey `  Stock` row of kind `line`, `    This character: %d`, `    %s: %d`, at most 5, then `    +%d more`). It also shows on endgame-only items. Verify in `tests/test_wording.lua` (order, the cap with `+3 more`, no block when nobody holds any) and `tests/test_tooltip_preview.lua` (the preview uses sample stock, never saved records).
- [x] 4.3 Item page "Your stock":
  - Build it from `Stock.Total`: the summary line, every holder, a grey age for other characters, and the "has none" line.
  - Remove `stockHelp`, the "(open your bank to count it)" branch and `Options.bankSeen`.
  - `toGet` is hidden while incomplete.
  - Keep the "You have enough." and "Still to get" strings.

  Verify in `tests/test_options.lua`:
  - Lines for three characters.
  - A holder appearing or disappearing while the page stays open changes the rows after `NotifyChange`.
  - Need minus total: range clamping (`Still to get: 0-15` becomes `You have enough.` at the top) and an unknown live bag count hides the row.
  - Still to get hidden when incomplete and shown when complete.
  - No bank prompt anywhere on the page.
- [x] 4.4 Auctionator quantity uses the realm-and-faction total; verify in `tests/test_auctionator.lua` (enough on another character gives no entry; part held elsewhere gives the difference; an incomplete total still uses the counted amount); on Era the export stays unavailable as today.
- [x] 4.5 Home "Login reminder" checkbox after Loot toast, hover text as specified. `profileToggle` takes the public key so it calls `P.Set("stock.reminder", ...)`. Add `entry("stock.reminder", "stockReminder", "boolean", nil, nil, true)` to `P.keys`, and `stock.reminder (on|off)` to `/kt help appearance`. Verify in `tests/test_options.lua` and `tests/test_presentation.lua` (the toggle and `/kt set` share one value; the "displays are off" note is unaffected).
- [x] 4.6 Login reminder: print the specified singular or plural line once per session at `PLAYER_LOGIN`, which covers both login and reload. Silent when nothing is missing or the setting is off; unavailable sources don't count. Verify in `tests/test_stock_recorder.lua` (2 characters plural, 1 singular, off silent, unavailable ignored, printed once per session).
- [x] 4.7 `/kt status stock`: a scope line (realm, faction, characters counted), then `<Name>: bank not counted.` / `mailbox not counted.` / `bank and mailbox not counted.`. `status` accepts the `stock` topic, and the topic lists name it. Verify in `tests/test_slash.lua`.
- [x] 4.8 The debug report lists the stock version, the characters in scope, missing and unavailable sources, and the reminder setting; verify in `tests/test_log.lua`.
- [x] 4.9 Codex visual review of the finished tooltip, item page, Home row and chat lines against the mockup (https://claude.ai/artifact/VC8mKt3xee8NkdVrmQyVcV; the reminder now also prints after `/reload`): indented holder rows, ages only on other characters, folding in its findings; verify `make test` and `make check` after the changes.

## 5. Docs and in-game checks

- [x] 5.1 Update the docs; verify `make test` (README command check, locale check) and `make check`:
  - `README.md`: stock across characters, the Login reminder, `/kt status stock` and `stock.reminder`. Good to know gets: realm and faction only, mail in transit not counted, more than 50 mails, cash-on-delivery, the 90 days, renamed or deleted characters, and two characters leveling the same profession. Replace the "bag count covers your bags, not the bank" line and the Auctionator lead.
  - `docs/listing.md` (feature bullet).
  - A new `docs/test-plan.md` section 9.
- [ ] 5.2 In game on Classic Era, with two characters on one realm and faction:
  - Counts after opening bank and mailbox on each.
  - A deposit keeps the total unchanged.
  - The tooltip line and Shift block.
  - The item page lines and Still to get.
  - The reminder at login and after `/reload`.
  - `/kt status stock`.
  - The Auctionator list.
- [ ] 5.3 The same checks on WoW Forever. Record in `docs/contracts.md` that the modern bank-tab path ran, and that mail attachments return an itemID.

## Workflow follow-up

- Archive (sync the specs, bump both TOCs to 0.3.0, and add a `## 0.3.0` CHANGELOG line, folding in the unpublished 0.2.2 icon line or leaving it), then commit, open the PR, merge, and tag `v0.3.0` when asked.
