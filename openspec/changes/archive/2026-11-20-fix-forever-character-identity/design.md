# Design

## Context

- **Stock identity today:** `Adapter.PlayerIdentity()` takes `UnitFullName("player")` as name and realm, and falls back to `GetNormalizedRealmName()` only when the second return is empty.
- **What Forever returns:** an in-game capture from another project, not measured by us, shows `UnitFullName` returning "Rambleon", "Birdsong" (name, surname) while `GetNormalizedRealmName()` returns the realm.
  - AceDB 40 confirms the surname model: under `RegionalUniqueNamesEnabled()` it keys characters "Name Surname" from `UnitNameUnmodified("player")` (docs/contracts.md, AceDB section).
- **Saved stock layout:** `realms[realm][faction][name]`. On Forever today that is `realms[surname][faction][firstName]`.
- **Profile rename:** `ProfileKey.Rename` moves `profiles[oldKey]` whenever the new name has no profile. It never checks `profileKeys`.

## Goals / Non-Goals

**Goals:**
- Forever stock is filed under the real realm and the full name, and existing records move without loss.
- Rename never moves a profile that another character's choice names.

**Non-Goals:**
- **Repairing saves already hit by the rename bug.** Which character owned the profile can't be told from the save. It needs two same-first-name characters on one realm, so it is rare.
- **The 0.4.3 Migrate ambiguity.** Two same-first-name characters had one shared old entry, and the first to log in takes it. The old save holds a single choice, so there is nothing to split.
- **Moving another alt's record before that alt logs in.** Its realm is unknown until then.
- **Any stock format or version change.**

## Decisions

- **D1. Realm from `GetNormalizedRealmName()` first.**
  - Fall back to `UnitFullName`'s second return only when surnames are off, then to `GetRealmName()` with spaces removed.
  - On Era, `GetNormalizedRealmName` returns the same normalized realm that `UnitFullName` gave, so Era keys don't change. A test pins that.
  - *Alternative:* detecting "the second return looks like a surname". Rejected because it is a guess; the realm call is unambiguous.
- **D2. Surname mode follows AceDB 40 exactly.**
  - When `RegionalUniqueNamesEnabled()` returns true and `UnitNameUnmodified("player")` gives a non-empty second return, the name is "Name Surname".
  - This picks the path by API result, not client name, and matches the profile key the settings library already uses.
  - Each stock row then shows the full name, which tells same-first-name alts apart.
- **D3. Move the record in plain Lua.** `Stock.Move(store, fromRealm, faction, fromName, toRealm, toName)` in `Model/Stock.lua`.
  - It moves only when the source is a table and the target is absent, then removes emptied faction and realm buckets.
  - `Core/Stock.lua` calls it at `PLAYER_LOGIN`, before the character is touched, only in surname mode, with `(surname, faction, firstName) -> (realm, "First Surname")`.
  - The adapter returns the surname as a fourth value, or nil, so the recorder never calls the game.
  - Full names are unique per region on Forever, so `realms[surname][faction][firstName]` belongs only to this character.
- **D4. Rename guard.** Before moving, `Rename` scans `sv.profileKeys`. If any key other than this character's new key has `oldKey` as its value, it returns false.
  - Both branches (active and not active) use the same guard.

## Risks / Trade-offs

- **[`UnitFullName`'s Forever return is only known from an outside capture]** → D1 no longer uses that return in surname mode, so either answer gives the right realm. In-game check 1 confirms it.
- **[A surname that equals a real normalized realm name]** → Only the exact `realms[surname][faction][firstName]` entry moves, and only into an empty slot, so another character's data is never overwritten.
- **[Alts show nothing until each logs in once]** → Same as a first install. README "Good to know" says so, and the login reminder already prompts.

## Migration Plan

- The data moves at each character's login. No version bump of the stock store.
- **Rollback:** 0.4.4 would read the moved records under the realm and full name, which it never looks up. Its own new records go back under the surname. No data is lost.
