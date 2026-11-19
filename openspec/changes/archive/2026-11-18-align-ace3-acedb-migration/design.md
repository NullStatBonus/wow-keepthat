# Design

## Context

See proposal.md (Why). Current state, verified in the repo:

- `KeepThat/Libs/VERSIONS.txt` names Release-r1403 (`d295b12`). The shipped modules match `embeds.xml`: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0, AceDB-3.0, AceConsole-3.0, AceGUI-3.0 (all widgets), AceConfig-3.0 (wrapper, Registry, Cmd, Dialog). No AceHook. The license file is `LICENSE-Ace3.txt`, and `THIRD_PARTY.md` refers to it by that name.
- Upstream `d295b12...ac3d122` touches these shipped files: AceDB-3.0.lua, AceConfigDialog-3.0.lua, and the ColorPicker, Heading, Icon and Label widgets. AceDBOptions, AceTab, `.luacheckrc` and `Ace3.toc` also change, but KeepThat does not ship them.
- `Core/Addon.lua` `OnInitialize` calls `AceDB:New("KeepThatDB", ns.defaults, true)`, then `ns.Presentation.Migrate(self.db.profile)`, then the starters. Nothing reads saved data before `New`.
- KeepThat never uses `db.char`, `db.realm`, `db.factionrealm` or the other per-key sections. Settings live in `db.profile`, and the log and stock live in `db.global`. Stock is keyed by `A.PlayerIdentity()`, not by AceDB keys, and `Core/Stock.lua` creates it at PLAYER_LOGIN, outside AceDB defaults. The only per-character AceDB state is the profile choice:
  - `Options.SetCharacterProfile(on)` calls `db:SetProfile(on and db.keys.char or "Default")`.
  - So a per-character profile is stored as `sv.profiles["Name - Realm"]`, selected by `sv.profileKeys["Name - Realm"]`.
- AceDB 33 builds `charKey = UnitName("player") .. " - " .. GetRealmName()`. On WoW Forever (`RegionalUniqueNamesEnabled()` true), AceDB 40 builds `UnitNameUnmodified("player")` name `.. " " ..` surname. In `initdb` it then writes `sv.profileKeys[newKey] = profileKey or "Default"` at once. AceDB 40's `SetProfile` raises an error for names that are empty, over 50 characters or only spaces.
- KeepThat's only color control has `hasAlpha = false` (`Options/Options.lua:79`). ColorPicker forces `a = 1` when the control has no alpha, so KeepThat's own pickers never showed the inverted-alpha bug. The fix reaches players through the shared AceGUI widget: LibStub runs the newest ColorPicker for every addon, so other addons' alpha pickers are fixed when KeepThat ships version 29.

## Goals / Non-Goals

**Goals:**
- Every Ace3 file KeepThat ships is byte-identical to upstream `ac3d122`, and identical to Closest Vendor's copy for the files both ship.
- A Forever character's per-character profile choice survives the new character key, whichever AceDB minor LibStub loaded.

**Non-Goals:**
- Migrating `db.char`, `db.realm`, `db.factionrealm` or other keyed sections. KeepThat stores nothing there. The new `realmKey` ("PvE" and similar) on Forever therefore has no effect.
- Renaming the old-named profile. It stays `sv.profiles["Name - Realm"]`.
- Adding or removing Ace3 modules, or changing `embeds.xml` or the TOC files.

## Decisions

### D1. Library files come from the upstream commit, not from a sibling addon
Get the `ac3d122` tarball from WoWUIDev/Ace3 and copy only the files KeepThat already ships, at the same paths, including the XML files. Closest Vendor ships only LibStub, CallbackHandler, AceGUI with widgets, AceConfigRegistry and AceConfigDialog, so it cannot supply AceAddon, AceEvent, AceDB, AceConsole, AceConfigCmd or the AceConfig wrapper. Its copies are a cross-check: the files both addons ship must hash the same.
*Alternative:* copy from Closest Vendor and fill the gaps from upstream. Rejected because it gives two sources for one commit.

### D2. Old key from a dedicated adapter read
Add `A.LegacyCharacterKey()` to `Core/Adapter.lua`. It returns `UnitName("player") .. " - " .. GetRealmName()`, with each call guarded and in `pcall`, and returns nil when either value is missing or empty. That is exactly AceDB 33's formula.
*Alternative:* reuse `A.PlayerIdentity()`. Rejected because it prefers `UnitFullName` and `GetNormalizedRealmName`. Those drop spaces ("Argent Dawn" becomes "ArgentDawn"), so the key would not match on such realms.

### D3. New key from the loaded AceDB
Use `db.keys.char`, which is what the loaded AceDB actually used. KeepThat does not copy AceDB's key logic, so the migration stays correct whichever minor LibStub loaded:
- On Era, and with an older AceDB loaded, old == new and the migration does nothing.
- With AceDB 40 on Forever, old != new.

### D4. Plain-Lua migration, run first
Put the migration in `Model/ProfileKey.lua` as `ns.ProfileKey.Migrate(db, oldKey)`, with no game globals, tested by `tests/test_profilekey.lua`. List it in both TOCs at the same position. `OnInitialize` calls it right after `AceDB:New` and **before** `Presentation.Migrate(self.db.profile)`. `SetProfile` replaces `db.profile`, so the restored profile must be the one that the presentation upgrade then runs on.

The steps:
1. Let `sv = db.sv`, `new = db.keys and db.keys.char`. Return if `oldKey`, `new`, `sv` or `sv.profileKeys` is missing, or if `oldKey == new`.
2. Let `chosen = sv.profileKeys[oldKey]`. Return if it is not a string.
3. If `db:GetCurrentProfile() == "Default"` and `chosen ~= "Default"` and `sv.profiles` holds `chosen`, call `db:SetProfile(chosen)` inside `pcall`. AceDB 40 raises an error for invalid names. On error, record it with `ns.Log.Failure` if available and keep the current profile.
4. Clear `sv.profileKeys[oldKey]` in all cases that reach step 2. Then no later login can apply the old choice again, even after the player switches back to the shared settings.

Rules covered:
- "New key already chosen, not overwritten": step 3 runs only while the new key is on "Default", the AceDB default this addon passes. A per-character choice already made under the new key (profile named after the new key) is kept.
- Second login: `profileKeys[oldKey]` is gone, so nothing happens.

KeepThat has no `db.char` data, so this scopes the decided "move `sv.char[old]` to `sv.char[new]`" step out. No data in that section would survive or be lost.

*Alternative:* a done flag in `db.global`. Rejected, because clearing the old entry carries the same information. An older AceDB can no longer load once KeepThat ships minor 40.

### D5. Provenance file
Rewrite `KeepThat/Libs/VERSIONS.txt` (keep its name, which `THIRD_PARTY.md` cites) in the format the sibling addons will share:
- Upstream URL and full commit hash, with the date retrieved.
- One line per module with MAJOR and MINOR, read from the shipped files.
- The license file name (`LICENSE-Ace3.txt`).
- Local patches: none.
- Update steps: download the commit tarball, copy the listed paths, record the minors, run the hash check against the sibling addons, `make test` and `make check`.

## Risks / Trade-offs

- [The restored profile keeps its old name. Turning "This character" off and on calls `SetProfile(db.keys.char)`, which creates an empty profile under the new name. KeepThat has no profile picker, so the old-named settings are then unreachable.] → Accepted for this patch. It needs a deliberate toggle off and on. Note it in `docs/test-plan.md`. A follow-up can make `SetCharacterProfile(true)` reuse the old-named profile, and can be filed as an issue.
- [A Forever player who, while another addon's AceDB 40 was loaded, chose the shared settings on purpose and still has an old-key choice gets the old choice back once.] → Not distinguishable from the bug case. The player can switch it back once, and it stays (step 4).
- [AceDB 40 reads client globals at file load (`UnitNameUnmodified`, `strlenutf8`, `RegionalUniqueNamesEnabled`, `C_GameRules`, `Enum.GameRule`). `tests/test_core.lua`'s `loadAceDB` stubs do not provide them.] → Extend the stubs. Forever-shaped tests run the real shipped AceDB 40.
- [`tests/test_smoke.lua` uses a fake AceDB with no `sv`.] → Step 1 returns early when `sv` is missing.
- [The changelog line about the color picker overstates the effect on KeepThat's own controls (see Context).] → Word it as a fix to color pickers with transparency on WoW Forever, or drop it. This is decided at archive.

## Migration Plan

The migration runs automatically on first load of 0.4.3 and needs no player action. Rollback means installing 0.4.2. AceDB 33 then reads the old key again, but step 4 cleared it, so a rolled-back Forever character uses the shared settings until it turns "This character" back on. The old-named profile is still there and is selected again by name.
