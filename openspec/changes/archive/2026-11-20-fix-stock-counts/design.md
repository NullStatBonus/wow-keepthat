# Design

## Context

How the stock recorder (`Core/Stock.lua`) works today:
- Every event only queues work, which is read on the next frame.
- `BANKFRAME_CLOSED` and `MAIL_CLOSED` drop pending work.
- Bank-slot and inbox events are ignored while the window is closed.
- `R.Tracked()` is cached for the session.
- Bank-tab IDs come from `C_Bank.FetchPurchasedBankTabData`. Only `BankTabBagID` falls back to `Enum.BagIndex.CharacterBankTab_N`.

## Goals / Non-Goals

**Goals:** never count a stale bank or mail reading, never delete a saved count because of a partial list, and never say "none" or "all counted" while unsure.

**Non-Goals:**
- **Reading the bank or mailbox after they close.** The game doesn't allow it.
- **Hooking the mail-take functions.** That brings taint risk for little gain.
- **Profession Journal's other off-toggle problems** (review #12). Those are planned for 0.4.7.
- **Mail beyond the 50 the inbox shows.** That limit is already documented.

## Decisions

- **D1. Tab ID fallback, else the list is unread.**
  - In `A.BankIDs()` on the tabs path, an entry without a numeric `.ID` takes `Enum.BagIndex.CharacterBankTab_<index>`.
  - If that is missing too, return nil. `queueBank` already treats nil as "keep the saved bank" and logs it once.
  - *Alternative:* skip the bad entry, which is today's behavior. Rejected: it deletes saved data.
- **D2. A window of 10 seconds after closing.**
  - The close handlers store `closedAt = A().Clock()`, separately for the bank and the mailbox.
  - A change within 10 seconds of that marks the source not counted:
    - a `PLAYERBANKSLOTS_CHANGED`, or a `BAG_UPDATE` for a container in the saved bank's `expected` list, deletes that container's record (`bank.c[id] = nil`). The source then reads as "missing", and the other containers keep their counts.
    - a `MAIL_INBOX_UPDATE` deletes `character.mail`.
  - A change already reported but still unread when the window closes counts the same way: `dirty` keeps the bank containers and the inbox that changed while open, and is cleared when they are read. The queue built when the bank opens is not "dirty", so a quick open and close forgets nothing.
  - Each case writes a debug line through `Log.Record`. It is not a failure.
  - Why a window and not "any event while closed": the game also sends bank and bag events at login and on zoning, and those must not wipe counts. A round trip to the server stays well inside 10 seconds.
  - *Alternative:* flush the pending reads when the window closes. Rejected because the late report hasn't arrived yet at that point.
- **D3. The tracked set follows the context.**
  - `R.Tracked()` caches the set together with the `Context.Get()` table it was built from, and rebuilds it when that table changes (any `Context.Invalidate`, including the start of Profession Journal).
  - It adds `ns.ProfessionJournal.Items(p)` for each `PJ.PROFESSIONS` entry when `ctx.extra` is set, which is the integration's working signal.
  - Containers read before the change don't hold the new items until they are read again. That is the same as any newly tracked material.
- **D4. "None counted yet."** In `stockLine`, when `total == 0` and the total is not complete, use the new string `L["None counted yet."]`.
- **D5. Unavailable sources at login.**
  - In `PLAYER_LOGIN`, after the character is set up, set `bank = { unavailable = true }` when `not A().BankAvailable()`, and `mail = { unavailable = true }` when `not A().MailAvailable()`.
  - These are the same checks the open handlers already make, and they are API-existence checks that are safe at login.
  - In `StockStatus`, when nothing is missing but the current character has an unavailable source, print `L["Every bank and mailbox this client can read is counted."]` instead of "Every bank and mailbox is counted."

## Risks / Trade-offs

- **[The game sends a bank or inbox event on every normal close]** → Every close would then mark the source not counted, and the reminder would nag. In-game checks 1 and 2 include a normal close that must stay counted. If that check fails, the fallback is to make the window start only when changes were still pending at close.
- **[The 10-second window misses a very slow server]** → The result is the old behavior, a stale count. That is no worse than today.
- **[Clock() has 1-second resolution]** → That is fine for a 10-second window.
