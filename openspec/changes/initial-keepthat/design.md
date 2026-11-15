# Design

## Context

This is a new repository; see proposal.md, "Why". Two sibling addons by the same author set the patterns:

- **Don't Do That** (`../wow-dontdothat`). Ace3 subset r1403 is committed under `Libs/` with `VERSIONS.txt`. AceConfig pages are built by pure functions. There are two TOCs (`_Vanilla` 11509 and `_Camelot` 16001) checked by `tools/check-*.sh`, a `luajit tests/run.lua` harness, and a `Debug/Probe.lua` that records which game APIs exist on the running client. Its tooltip line is added with `tooltip:AddLine` inside `pcall`.
- **Closest Vendor** (`../wow-closest-vendor`). Every game call lives in `Adapter.lua`, guarded and in `pcall`, and returns nil when missing. Logic modules use no game globals. Visuals are OLED-safe. Third-party data is credited in `THIRD_PARTY.md`.

The two clients differ in ways we have not fully checked. WoW Forever mixes Classic and Retail APIs; for example DontDoThat's probe checks for `TooltipDataProcessor`, `C_Item.*` and `C_TradeSkillUI.*`. Every client-dependent path therefore needs two branches, chosen by a capability check, never by the client name.

## Goals / Non-Goals

**Goals:**
- A skeleton another addon can copy file for file. Only the addon name, the data and the feature modules change.
- Pure-Lua classification, routes and wording, fully covered by `make test` without a game client.
- Each integration is one file that can fail alone.
- No per-frame work. Tooltip, toast and overlay work happens only on events or hooks.

**Non-Goals:**
- A runtime recipe scanner. The catalog is generated at build time and shipped; we do not read the player's profession window to build it.
- Supporting bag addons beyond the four in the specs, or a generic "any button" overlay.
- Localized catalog text in v1. Item and recipe names come from the client, so they are already localized; the addon's own sentences go through `L[...]`.

## Decisions

### D1. Layout: Don't Do That's folders plus Closest Vendor's adapter rule

```
KeepThat/
  KeepThat_Vanilla.toc, KeepThat_Camelot.toc, embeds.xml, Libs/ (Ace3 r1403 subset)
  Locales/enUS.lua
  Core/      Init.lua, Addon.lua (AceAddon, AceDB, events), Adapter.lua (all game calls), Slash.lua
  Data/      Catalog_Era.lua, Catalog_Forever.lua, Routes_Era.lua, Routes_Forever.lua (generated; do not edit by hand)
  Model/     Classify.lua, Leveling.lua, Wording.lua   (pure Lua)
  UI/        Tooltip.lua, Toast.lua, Overlay.lua
  Integrations/ Blizzard.lua, Baganator.lua, Bagnon.lua, EllesmereUI.lua,
                Auctionator.lua, ProfessionJournal.lua
  Options/   Options.lua (pure builders -> AceConfig groups)
  Debug/     Log.lua, Probe.lua, Export.lua
tests/ tools/ docs/ .github/workflows/{ci,release}.yml .pkgmeta Makefile LICENSE THIRD_PARTY.md CHANGELOG.md CLAUDE.md
```

Why: the user wants one framework across addons. Don't Do That already uses Ace3, and Closest Vendor's rule keeps the logic testable. Alternative considered: a shared library addon (an "embed") for the common skeleton. Rejected for now, because copying is simpler until a third addon proves which parts are really shared.

### D1b. Integrations gated to WoW Forever in this version

Each `Integrations/*.lua` starts only when `ns.client == "forever"`. On Classic Era, the Integrations page shows one line saying integrations are not yet available there. A later change lifts the gate for each integration once it is verified on Era.

### D2. One catalog for each client, generated from that client's DB2 tables and curated by hand

`tools/build-catalog.py --client era|forever` reads that client's recipe tables from wago.tools (SkillLineAbility, spell reagents and item names, from the Classic Era build or the Forever build) and writes `Data/Catalog_Era.lua` or `Data/Catalog_Forever.lua`. Endgame membership comes from reviewed lists, `tools/endgame/<client>/<profession>.txt`: item IDs, each with a source citation and a reason (consumable, a class's best-in-slot gear, essential). The generator fills in recipes and quantities, and the curated list decides membership. Each TOC lists only its own client's data files (`_Vanilla.toc` loads `Data/*_Era.lua`, `_Camelot.toc` loads `Data/*_Forever.lua`), so the game loads only the running client's data, about 300 KB or 450 KB, and code never has to tell the clients apart. `ns.client` is taken from the loaded catalog's `client` field. `make check` treats the per-client file pairs as one entry when it compares the TOCs.

Why separate catalogs: Forever moved recipes between professions (the potion line under First Aid), so a shared catalog with client flags would be wrong in many places. Why not rules applied to DB2 alone: they over-flag (Thorium Bar is in hundreds of recipes), and pure hand data drifts from game data. Alternative considered: scraping guide or database sites. Rejected, because of their terms and fragility; they are cited sources for the curated lists, not scrape targets.

### D2b. Expanding materials made from other materials

Both generators share one rule for walking down a recipe chain. They expand an item when exactly one recipe on that client makes it, and that recipe's name is not an element conversion (`Transmute: X to Y`). The walk stops after four levels and at items already visited. `tools/no-expand.txt` lists exceptions, items that are mostly gathered or dropped even though a recipe can make them. Each added entry records `via`, the item it is used to make, so the tooltip can say "used to make Thorium Bar for Arcanite Bar". For endgame, `build-catalog.py` adds the inputs to the same profession's endgame entries. For leveling, `build-routes.py` first works out, per guide and profession, how much of each intermediate the route needs and how much its own steps craft. It then adds inputs only for the shortfall, as segments over the consuming steps' skill ranges, so a route that crafts its own bolts is not counted twice.

### D3. Leveling materials as the union of the cited guides

`tools/routes/<client>/<guide>/<profession>.yaml` records one guide's route as facts only (`from`, `to`, `recipe` as a spell ID, `crafts`), with the guide's URL and the date it was checked. The guides are:
- Classic Era: wow-professions.com and Wowhead Classic.
- WoW Forever: Metabot and RankedBoost. Icy Veins and Mobalytics refuse automated reads.

The generator multiplies crafts by reagent quantities from that client's DB2, and writes `Data/Routes_<Client>.lua` as, per profession and material, a list of `{ guide, from, to, total }` segments. At runtime `Model/Leveling.lua` does three things for each material:
- **Marks it** if any source has a segment ending above the current skill.
- **Counts** a range: each source's remaining need is the sum of its segments above the current skill (part of a segment counts in proportion), and the range runs from the smallest to the largest need over the sources. A segment can carry a low and a high count itself, for guides that give a range per block. A count-less segment marks the material but adds nothing to the count.
- **Names** the sources that use it.

There is no route setting.

Why the union and a range: the goal is to keep materials, not to follow a route. The top of the range covers any common route, and the range shows how much the guides agree, so the player can choose how much to keep on hand. Alternative considered: one built-in route plus a route selector. Rejected: the user does not want to pick a route.

### D4. Profession Journal read at runtime through a guarded adapter

`Integrations/ProfessionJournal.lua` (WoW Forever only) reads `DFLProfessionJournalNS.GuideData[key].steps`, the static reviewed route that ships in the core addon. It passes the steps through Profession Journal's own `Leveling.OrderedSteps(steps, API.Faction())` and maps each skill step's `from`, `to` and `materials[].total` into the same segment format as `Routes_<Client>.lua`, as one more source named "DFL Profession Journal". Before trusting the data, it checks the shape: the steps are a list, and each step has numeric `from` and `to` and a list of `materials`. If the check fails, it returns nil and only the built-in sources are used. Nothing from it is ever saved. Its live `Leveling.Guide` is not used, because its numbers change with the player's bags and prices. Links use `UI:OpenRecipeInJournal(key, spellID, name)`. The contract is in `docs/contracts.md`.

Why: the user wants the numbers to agree with this widely used guide, and its All Rights Reserved license rules out copying its data.

### D5. Tooltip hook chosen by capability

`Adapter.HookItemTooltips(fn)` uses `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` when it exists. Otherwise it uses `HookScript("OnTooltipSetItem")` on GameTooltip, ItemRefTooltip and the shopping tooltips. A once-per-tooltip guard is cleared on `OnTooltipCleared`. When Shift is pressed or released (`MODIFIER_STATE_CHANGED`), the visible tooltip is refreshed so the details appear or disappear. The text comes from the pure `Model/Wording.lua`, and the line is added the way Don't Do That adds its line (`AddLine` inside `pcall`).

Why: Forever may have either API; branching on capability covers both clients and future patches.

### D6. Loot toast from the player's loot messages

On `CHAT_MSG_LOOT` messages for the player's own loot, `LOOT_ITEM_SELF` and `LOOT_ITEM_SELF_MULTIPLE` are matched as patterns converted from the client's localized format strings, giving the item link and count. Purchases, mail and trades do not produce these messages, which matches the spec. A session table keyed by item ID implements "one toast per item per session". The toasts are a small pool of three frames that ignore the mouse (`EnableMouse(false)`), fade with `C_Timer`, and have a dark background with no bright fixed fill, which is OLED-safe. Fallback, if the spike shows Forever's loot messages differ: compare bag counts on `BAG_UPDATE_DELAYED`, while the loot window or auto-loot is active.

Alternative considered: the game's own alert system (`AlertFrame`). Rejected, because it is not on Classic Era and it does not support combining pickups.

### D7. Overlay: one texture per button, refreshed by each integration's own hook

`UI/Overlay.lua` owns `Apply(button, itemID)`. On first use it creates a texture with `ADD` blend on the button, colors it from the settings, and shows or hides it from `Classify`. Each integration only finds buttons and calls `Apply`:

| Target | How buttons are found |
|---|---|
| Blizzard | `hooksecurefunc("ContainerFrame_Update")` and the bank frame update, falling back to `ContainerFrame_UpdateItems` and the C_Container update functions, chosen by capability |
| Merchant (both clients) | `hooksecurefunc` on `MerchantFrame_UpdateMerchantInfo` and `MerchantFrame_UpdateBuybackInfo`; each `MerchantItem<i>ItemButton` reads its item from `GetMerchantItemID` (page-aware index) or the item link, and the buyback tab from `GetBuybackItemLink` |
| Baganator | its internal `Baganator*ItemButtonMixin` `SetItemDetails` (its only documented hook, `RegisterCornerWidget`, draws in one corner); item from `button.BGR.itemID` |
| Bagnon | hooking its item button's `Update` method |
| EllesmereUI | its public painter API, `EUI_Bags.RegisterItemOverlayIcon("KeepThat", fn(btn, data))`. The item comes from `data.info.itemID`, never from the button. Our texture is parented to `btn._textOverlay` and kept in our own table keyed by button. Repaint by calling `EUI_Bags.RefreshInventory` and `EUI_BankFrame.RefreshBank` (see `docs/contracts.md`) |

Each integration runs its first `Apply` inside `pcall`. Any error disables that integration for the session and logs it (spec: failure is contained). When a color or setting changes, every known button is re-colored; there is no rescan of bags.

Why: one owner for drawing makes the colors and the toggle for each location consistent, and integrations stay thin.

### D8. Settings in AceDB, material toggles stored as exceptions

Defaults are in one `defaults` table, as the specs list them. Material toggles store only the materials the player turned off (`disabled[itemID] = true`), so materials added in an update start on, and a change to the catalog never invalidates saved settings. The account-wide `Default` profile is used, and AceDBOptions is not embedded in v1. The per-character profile option is a toggle that switches to a profile named after the character.

### D9. Auctionator export through its public v1 API

`Integrations/Auctionator.lua` uses `Auctionator.API.v1` when it exists (creating a shopping list from search strings that include a quantity), and is disabled otherwise. List names start with `KeepThat:`, and only those lists are replaced.

### D10. Release pipeline copied as is

`.pkgmeta`, `ci.yml` and `release.yml` are copied from Don't Do That with the names changed. The project IDs are added once the user creates the CurseForge and Wago projects.

## Risks / Trade-offs

- [EllesmereUI Bags is undocumented and may not run on Forever] → Spike first (task 1.1). If it can't be supported, ship v1 without it and remove it from the listing.
- [Profession Journal's data layout is private and changes] → Check its shape on every load and fall back quietly; ask its author for an API.
- [The curated endgame lists are subjective] → Cite a source for every entry, let players turn any material off, and treat list changes as patch releases.
- [Tooltip noise from items used by many professions] → One line, at most two professions shown plus `+N`, and the details only while Shift is held.
- [Too many toasts while gathering] → One toast per item per session, at most three at once, off by default.
- [Overlay cost in large bags] → Classification is a table lookup with no allocation, done only in update hooks.
- [Wowhead terms] → Wowhead is used for citations and links only, never scraped.

## Migration Plan

Not applicable; this is a first release. Version 0.1.0 is tagged after archive, as in the sibling addons' release flow.

## Open Questions

- The exact CurseForge and Wago project IDs. They are needed only before the first tagged release.
- Whether a chosen guide's route needs different counts on Forever than on Era. The data model already supports client flags, so the answer changes data, not design.
