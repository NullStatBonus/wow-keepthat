# Client and addon contracts

What the game and other addons actually provide, as measured with `/kt probe` (task 1.3). Code picks a path by checking that an API exists (see `CLAUDE.md`), and this file records which path each client takes. Mark an entry "unverified" until a probe has confirmed it.

## WoW Forever (1.60.1, build 70938, interface 16001)

Measured 2026-11-15, with EllesmereUI 9.8.6 (Bags module), Auctionator 347 and DFL Profession Journal 3.16.76 loaded.

### Client APIs

- **Tooltips:** `TooltipDataProcessor.AddTooltipPostCall` and `Enum.TooltipDataType.Item` exist; `GameTooltip` has no `OnTooltipSetItem` script. Use the post-call path (design D5).
- **Items:** the old globals `GetItemInfo`, `GetItemInfoInstant` and `GetItemCount` are **missing**; use `C_Item.*`.
- **Containers:** only `C_Container.*` (47 functions). `ContainerFrame_Update`, `ContainerFrame_UpdateItems` and `BankFrameItemButton_Update` are missing; `ContainerFrameCombinedBags` and `BankFrame` exist. The Blizzard bag integration has to hook the item button mixins or the combined bag frame, not the old update functions.
- **Skills:** `GetNumSkillLines` and `GetSkillLineInfo` are missing; `C_SkillInfo` has `GetNumSkillLines`, `GetSkillLineInfo`, `GetSkillLineInfoByID`, `ExpandSkillHeader` and `CollapseSkillHeader`. Its rows are `SkillLineAttributes` tables with `name`, `isHeader`, `isCollapsed` (no `isExpanded`) and `rank` (wow-api, build 1.60.1.71037, 2026-11-21). `C_TradeSkillUI` exists (147 functions).
- **Frames:** `GetMouseFocus` is missing and `GetMouseFoci` exists. `Settings.RegisterCanvasLayoutCategory` exists and `InterfaceOptions_AddCategory` is missing, so AceConfigDialog's Settings path is the one used.
- **Addons:** only `C_AddOns.*`; the old globals (`GetNumAddOns`, `IsAddOnLoaded`) are missing.
- **Loot strings** (no full stop at the end):
  - `LOOT_ITEM_SELF` = `You receive loot: %s`
  - `LOOT_ITEM_SELF_MULTIPLE` = `You receive loot: %sx%d`
  - `LOOT_ITEM_PUSHED_SELF` = `You receive item: %s` (quest rewards, crafting and similar; never toasted, per `loot-toast`)
  - `LOOT_ITEM_PUSHED_SELF_MULTIPLE` = `You receive item: %sx%d`

### EllesmereUI Bags (EllesmereUIBags 9.8.6)

- It runs on Forever; `EUI_CLIENT_FOREVER` is a global boolean.
- Main bag frame: `EUI_MainBagFrame` (also reachable as `EUI_Bags`). Bank: `EUI_BankFrame`. Reagent bag: `EUI_BagsReagent`.
- **It has a public overlay API**, documented in `EllesmereUIBags/EUI_Bags_Slots.lua` (source: github.com/EllesmereGaming/EllesmereUI, 9.8.6; the TOC lists interface 16001):
  - `EUI_Bags.RegisterItemOverlayIcon(name, updateFn)` and `EUI_Bags.UnregisterItemOverlayIcon(name)`.
  - `updateFn(btn, data)` runs for every painted slot in the bags, the reagent bag and the bank, in both grid and list view, through `securecallfunction`, so an error in our painter is reported and never stops their render.
  - `data = { bag, slot, info, itemLink }`, valid only during the call (the bank reuses one table). Placeholder slots pass bag 0, slot 0 and no item. `info` is the `C_Container.GetContainerItemInfo` result; take the item ID from `info.itemID`.
  - Rules: keep no state on `btn` (it is a secure button), parent our textures to `btn._textOverlay` (it covers the item icon, in list rows too), track them in our own table keyed by button, and never touch the button from a click handler.
  - EllesmereUI's own Quick Actions module uses the same API to draw a shade over items, which is the same kind of drawing as our tint.
- This replaces design D7's "decided by the spike" for EllesmereUI: register a painter, keep one texture per button in our own table, and show or hide it from `data.info.itemID`. To repaint after a setting changes, call `EUI_Bags.RefreshInventory` and `EUI_BankFrame.RefreshBank`, both of which the probe saw.
- Item buttons are anonymous `Button`s under a ScrollFrame in `EUI_MainBagFrame`, and use Blizzard's item button mixin: `GetSlotAndBagID()` returns slot, bag (seen as `8, 1`, and `1, 2` on an occupied slot). **`GetItemID()` and `GetItemLink()` return nil even on an occupied slot**, so never read the item from the button; use the painter's `data`, or `C_Container.GetContainerItemID(bag, slot)`.

### Auctionator (347)

- `Auctionator.API.v1` exists with 21 functions, among them `CreateShoppingList`, `AlterShoppingListItem`, `DeleteShoppingListItem` and `ConvertToSearchString`. This fits design D9.
- From `Source/API/v1/ShoppingLists.lua` (read from a public mirror of Auctionator's source):
  - `CreateShoppingList(callerID, name, searchStrings)` **replaces** a list that has the same name, and starts searching at once if the auction house is open.
  - `ConvertToSearchString(callerID, term)` takes `{ searchString, isExact, quantity, ... }`, so the quantity still needed goes in `term.quantity`.
  - Use `callerID = "KeepThat"`.

- **Prices.** Probe 2026-11-22, Auctionator 351 on WoW Forever 1.60.1 (build 71037): `Auctionator.API.v1` has 21 functions, among them `GetAuctionPriceByItemID`, `GetAuctionAgeByItemID`, `IsAuctionDataExactByItemID` and their `ByItemLink` forms. Sampled for Runecloth (item 14047): `GetAuctionPriceByItemID` = 507 (copper), `GetAuctionAgeByItemID` = 1 (day), `IsAuctionDataExactByItemID` = true. The semantics below come from a source review of a public fork (`etkr/Auctionator`, last pushed 2025-05), and the samples agree with it:
  - `GetAuctionPriceByItemID(callerID, itemID)` returns the last scanned price in copper, or nil when none is known or `Auctionator.Database` is not ready. Its README calls this API stable.
  - `GetAuctionAgeByItemID(callerID, itemID)` returns the days since the item was last seen in the auction house, and nil when it was never seen or more than 21 days ago.
  - `IsAuctionDataExactByItemID(callerID, itemID)` is true when a stored price exists.
  - A call with a bad `callerID` or a non-number itemID raises an error, so every call stays in `pcall`.
  - KeepThat counts a price only when the age is also a number.

### DFL Profession Journal (3.16.76, re-checked at 3.16.97)

#### Re-check, 3.16.97 (2026-11-27; CurseForge release of 2026-11-17, read from a scratch copy, nothing copied)

- Forever only: interface 16001, no Classic Era build.
- Still present, unchanged in shape: `DFLPJ_OpenPage`, `DFLPJ_ToggleJournal`, `DFLPJ_ToggleTracker`, `Leveling.OrderedSteps(steps, faction)`, `API.Faction()`, `UI:OpenRecipeInJournal(profession, spellID, name)`, and the "Your route" tooltip row behind `tooltipUse`.
- Route data: the changelog from 3.16.76 to 3.16.97 lists no route-data change and the pipeline id is still `dfl-professions-2026-09-27`, but `DataCore.lua` is about 0.2% larger (3,031,455 bytes against 3,025,871). Treat route values as unverified between the two builds.
- New: a LibDataBroker launcher (`Broker.lua`) beside the minimap crest, Farming pages for Riverglades, Zephras Isle, Mount Hyjal and Shen'dralas, loot and vendor-price recording from the player's own play (`/pj loot`), and an auction-window Make, Materials and Post redesign.
- `GuideComparisonData.lua` names other Forever guides it compared against: wow-professions.com/forever, classicwowforever.com and zockify.com, with dates from 2025-02 to 2026-09.


- Folder `DFLProfessionJournal`, plus a load-on-demand data addon for each profession: `DFLProfessionJournal_Data_<Profession>`. On login only Alchemy, Cooking, Engineering, FirstAid, Fishing, Herbalism and Skinning were loaded; the others probably load when that profession is opened.
- Namespace exposed as the global `DFLProfessionJournalNS` (102 keys), including `API`, `Integration`, `Leveling`, `GuideData`, `ActiveGuide`, `CurrentStep`, `FindRecipe` and `ItemFacts`.
- Global functions: `DFLPJ_OpenPage`, `DFLPJ_ToggleJournal`, `DFLPJ_ToggleTracker`. `DFLPJ_OpenPage` is the likely deep-link entry point.
- Saved variables `DFLProfessionJournalDB` (settings, prices, characters). We never read or write these.

#### Source review (3.16.76, local copy in `../DFLPJ`; All Rights Reserved, read only to integrate, nothing copied)

- **Profession keys** are lowercase: `alchemy`, `blacksmithing`, `enchanting`, `engineering`, `leatherworking`, `tailoring`, `cooking`, `firstaid`, `mining`, `herbalism`, `skinning`, `fishing`. `API.SkillLineID[key]` gives the skill line (Tailoring 197).
- **Route data is static and always loaded.** `DFLProfessionJournalNS.GuideData[key].steps` is defined in the core addon (`DataCore.lua`), not in the load-on-demand data addons. There are also variants such as `alchemy_no_herbalism`. The pipeline id is `GuideData[key].pipeline` (`dfl-professions-2026-09-27`), which we record as the source version.
- **One step:**
  - `kind`: `"skill"`, `"training"` or `"gap"`.
  - `from` and `to`: the skill range.
  - `number`.
  - For skill steps: `crafts` (average), `planFor` (8 runs in 10), `recipe` (name), `spellID`, and `make = { itemID, count, name, spellID }`.
  - `materials`: a list of `{ itemID, name, total, source }`, where `total` is the quantity for the whole step.
  - Gathering routes put Horde-only rows in `group = "Horde route"`.
- **Faction ordering:** `Leveling.OrderedSteps(steps, faction)` filters the faction rows, splits brackets at training points and renumbers. `faction` is `"Horde"` or `"Alliance"` (`API.Faction()`). It works on a copy and does not change `GuideData`.
- **`Leveling.Guide(key, mode)`**, with mode `"cheapest"` or `"fastest"`, gives the live annotated plan. It depends on bags, known recipes and prices, and is cached by a signature. We do not use it for counts, because its numbers change with the player's stock. **Use `OrderedSteps(GuideData[key].steps, API.Faction())` and sum `materials[].total` over steps with `to > current skill`.** That matches `leveling-guidance` ("counts reflect current skill").
- **Deep links:**
  - `DFLProfessionJournalNS.UI:OpenRecipeInJournal(key, spellID, name)` opens the recipe's page in Profession Journal's own window and returns false when it can't.
  - `API.OpenRecipe(spellID, key)` opens the game's profession window at that recipe (the profession must be known).
  - `DFLPJ_OpenPage(page)` opens a named journal page.
  - `API.OpenProfession()` is **not** a link: it returns the profession whose window is open.
- **Its tooltip lines.** On every item tooltip, Profession Journal adds rows through `TooltipDataProcessor`:
  - auction price;
  - "Recipe: Known/Not learned" for recipe items;
  - **"Your route: <next use>" for materials on the player's route**;
  - "Farm" or "Made from" sources;
  - disenchant values while Shift is held, if the user turns that on.

  Each group can be switched off in its settings (`tooltipPrice`, `tooltipUse`, `tooltipSource`, `tooltipDisenchant`). **"Your route" repeats our leveling line**, which needs a decision (see Open questions).

#### EllesmereUI Bags members (probe round 2)

- `EUI_Bags.itemOverlayIcons` is a table (empty when no overlay is registered), alongside `RegisterItemOverlayIcon`, `UnregisterItemOverlayIcon` and `RunItemOverlays`, so overlays are registered by key and run on refresh. `_slotPinLevel` is 10 (frame level for slot overlays).

### Open questions (next probe)

- When Profession Journal shows "Your route" on a material, should KeepThat still add its `Leveling:` line (a duplicate), or leave leveling to Profession Journal and show only `Endgame:`? This changes the `material-tooltip` spec.
- Lua errors at login: none (Forever, round 2).

## Bag addons (from source review, task 7)

#### Baganator

- **Source read:** the mirror github.com/doneykoo/Baganator, shallow clone at commit `f1e4df9`, dated 2024-07-12.
  - Its TOC lists interface 100207, 110000, 40400, 30403 and 11503, with no 16001.
  - Nothing here is verified on Forever. Probe it when Baganator is installed there.
- **Public item-button API** (`API/Main.lua`):
  - `Baganator.API.RegisterCornerWidget(label, id, onUpdate(cornerFrame, details) -> bool, onInit(itemButton) -> frame, defaultPosition)`;
  - `Baganator.API.IsCornerWidgetActive(id)`;
  - `Baganator.API.RequestItemButtonsRefresh()`, which fires `ContentRefreshRequired` on the next frame;
  - `RegisterJunkPlugin`, `RegisterItemSetSource`, `RegisterContainerSort` and `RegisterGuildBankSort`;
  - `Baganator.API.Skins.*`.
- **Why corner widgets cannot draw the tint:** `ItemViewCommon/ItemButton.lua` `UpdateSettings` shows only the first widget whose `onUpdate` returns true in each corner, and only widgets the player has placed in a corner array. A full-icon tint registered there would hide the item level or BoE text in its corner, or never show.
  - Registering the same `id` twice fails an assert.
- **What KeepThat hooks instead** (internal globals; this departs from design D7's "documented widget API"):
  - It runs `hooksecurefunc` on `SetItemDetails` of these mixins:
    - `BaganatorRetailLiveContainerItemButtonMixin`, `BaganatorClassicLiveContainerItemButtonMixin`;
    - `BaganatorRetailCachedItemButtonMixin`, `BaganatorClassicCachedItemButtonMixin`;
    - `BaganatorRetailLiveWarbandItemButtonMixin`.
  - These are defined in `ItemViewCommon/ItemButton.lua`, and the XML templates in `ItemButton.xml` apply them with `mixin=`.
  - The template copies the mixin when a button is built, so the hook must be in place before the first bag view is built. KeepThat starts at login, so it is.
  - After `SetItemDetails`, `button.BGR` is set synchronously (`GetInfo` uses `Syndicator.Search.GetBaseInfo`), and `button.BGR.itemID` holds the item. This also works for cached and other-character views.
  - On live layouts, the button's parent is an index frame whose `GetID()` is the bag ID (`BaganatorLiveBagLayoutMixin:RebuildLayout`, `Layouts.lua`). Cached layouts set the index frame ID from `cacheData.bagID`. The bank rule for those views is unverified.
  - Until at least one of these mixins exists with `SetItemDetails`, Baganator counts as not detected. The gate tries again whenever another addon finishes loading and at login, so mixins that appear after KeepThat starts are still hooked. If mixins exist but none can be hooked, the integration fails with "no Baganator item button mixin with SetItemDetails could be hooked (N found)".
- **Baganator 860 (installed copy, read 2026-11-15):** TOC interface 120100, 120105, 16001, 50504, 38001, 20506 and 11509. `ItemViewCommon/ItemButton.lua` still defines the global mixins `BaganatorRetailCachedItemButtonMixin`, `BaganatorRetailLiveContainerItemButtonMixin`, `BaganatorClassicCachedItemButtonMixin` and `BaganatorClassicLiveContainerItemButtonMixin` (plus the two guild mixins), each with `SetItemDetails`, at file scope. `BaganatorRetailLiveWarbandItemButtonMixin` no longer exists. In game on WoW Forever the mixins exist, but `hooksecurefunc` on them fails with "attempted to perform indexed assignment on a frozen table": `ItemButton.lua:1482-1489` calls `table.freeze` on all six mixins when `table.freeze` exists.
  - Forever uses the Retail templates (`Pools.lua`: `IsRetail or IsForever`), built with `CreateFramePool` and unnamed, so buttons cannot be found by global name.
  - Each button has its own copy of the methods (the template's `mixin=`), and those copies are not frozen.
  - Every button is reported through the public skin API: `Skins.AddFrame("ItemButton", button)` (`Skins/Initialize.lua:85`, called from `Layouts.lua`, `BackpackView.lua`, `ContainerSlots.lua`) records it in `Baganator.API.Skins.GetAllFrames()` and calls each `Baganator.API.Skins.RegisterListener(callback)` listener with `{ regionType, region, tags }` (`API/Main.lua:303-309`). Live buttons are preallocated at login.
  - `GetInfo` sets `self.BGR` synchronously inside `SetItemDetails` (`ItemButton.lua:192-194`).
  - So KeepThat adopts every `ItemButton` reported so far and each new one: a button whose `SetItemDetails` is still one of the bag mixins' own functions gets its own `SetItemDetails` hook and is painted at once. Bag-slot and live guild buttons carry other methods and are skipped. A hook that fails is not marked done, so a later report retries it. Older Baganator without frozen mixins keeps the mixin hook, and buttons built before that hook are still adopted.
  - Cached layouts (other characters, the bank while away) parent their buttons to the layout frame, which has no bag ID (`Layouts.lua:296-321`, `1028`), and cached guild layouts use the same cached pool (`Layouts.lua:1058`). So bags or bank comes from the view's frame name: `Baganator_SingleViewBankViewFrame<n>`, `Baganator_CategoryViewBankViewFrame<n>`, `..BackpackViewFrame<n>`, `Baganator_SingleViewGuildViewFrame<n>` (`ViewManagement/Initialize.lua:150-358`). Guild views are not tinted.
  - `Baganator.API.RequestItemButtonsRefresh` now fires `RefreshStateChange` (`API/Main.lua:21-28`), not `ContentRefreshRequired`.
  - Corner widgets are created only for plugins the player placed in a corner (`ItemButton.lua:283-290`), so `RegisterCornerWidget` still cannot carry the tint.

#### Bagnon

- **Source read:**
  - Bagnon 12.1.10, whose TOC lists interface 120105, 50504, 40402, 30404, 20506, 16001 and 11509.
  - BagBrother at commit `867dd51`, dated 2026-11-14, from github.com/Jaliborc/BagBrother.
  - Poncho-2.0 and WildAddon-1.1 from github.com/Jaliborc.
  - All Rights Reserved: read only to integrate, nothing copied.
- **Global and classes:**
  - Bagnon's `main.xml` includes BagBrother's `core/core.xml`, so BagBrother's files run under Bagnon's namespace.
  - WildAddon `NewAddon` puts that namespace in `_G`, so the global `Bagnon` is the namespace.
  - `Base:NewClass` (`core/classes/base.lua`) stores every class as `Addon[name]`, which gives `Bagnon.Item` (`core/classes/item.lua`) and `Bagnon.ContainerItem` (`core/classes/containerItem.lua`, which overrides `Update`).
- **Update path:**
  - `Item:Update(info)` sets `self.info` (a container item info table with `itemID`, `hyperlink`, `quality`, `stackCount` and so on), then redraws.
  - `ContainerItem:Update(...)` calls the super, then the cooldown and slot color.
  - `self.bag` holds the bag ID (`Item:New(parent, bag, slot)`), and `GetID()` holds the slot.
  - Offline and other-character views fill `info` from the cache, so the item has to come from `self.info.itemID`, never from `C_Container`.
- **Method binding:** `Item:Bind` copies the class methods into each button with `Mixin`, from a list cached on the class as `__bindList` and built when the first button is made.
  - So a `hooksecurefunc(Bagnon.ContainerItem, "Update", fn)` reaches only buttons built after the hook, and only while the list is not cached yet.
  - KeepThat also hooks `__bindList.Update` when the list exists, and logs that buttons built earlier show no tint until a reload.
- **Plugin hooks:** `Item.UpdateSecondary = nop`, marked "backwards support", is the old plugin hook point. It still runs on every update.
- **Repaint:** `Bagnon.Frames:Update()` sends `UPDATE_ALL` to every item group, which re-runs `Layout`. KeepThat does not need it: `Overlay.Refresh` re-colors the buttons it knows.
- **Bag numbers:** BagBrother builds `InventoryBags` from `BACKPACK_CONTAINER .. NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS`, plus `KEYRING_CONTAINER`. `BankBags` holds `BANK_CONTAINER`, the bags up to the last bank bag, and `REAGENTBANK_CONTAINER`. `A.BagLocation` uses the same split.

#### EllesmereUI Bags (additions)

- **Refresh calls are methods:**
  - `EUI_Bags:RefreshInventory()` is in `EUI_Bags_Refresh.lua`.
  - `RefreshBank` is a method of the frame named `EUI_BankFrame` (`EllesmereUIBags_Bank.lua`, `local EUI_Bank = CreateFrame("Frame", "EUI_BankFrame", ...)`), so call it as `EUI_BankFrame:RefreshBank()`.
- **Painter errors are not silent:**
  - `RunItemOverlays` calls each painter through `securecallfunction`. That keeps EllesmereUI's render going, but the error still reaches the error handler.
  - KeepThat therefore wraps its painter in its own `pcall`. On error, it turns itself off, unregisters `"KeepThat"` and logs the failure.
- **The addon folder:** `EUI_Bags` comes from the `EllesmereUIBags` addon folder. Its TOC lists interface 120000 to 120105 and 16001.

#### Blizzard bags (unverified, record from `/kt log`)

KeepThat picks the update path by capability, in this order:
1. `ContainerFrame_Update`, expected on Classic Era.
2. `ContainerFrame_UpdateItems`.
3. Otherwise, `UpdateItems` on `ContainerFrameCombinedBags` and `ContainerFrame1..NUM_CONTAINER_FRAMES`, iterating `EnumerateValidItems()` or `Items`. Expected on Forever.

The bank path is chosen separately:
- `BankFrameItemButton_Update` when it exists, for the main bank slots on Classic Era;
- `BankPanelItemButtonMixin.Refresh`, using `GetBankTabID()` and `GetContainerSlotID()`, on modern clients.

Forever's probe showed `BankFrame` but not which of these exists, so check the bank on Forever (test plan check 4.1).

## Classic Era

Not yet probed.

- **Skills (from Armory-Classic's source, 2026-11-21):** `GetNumSkillLines` and `GetSkillLineInfo(i)` list only the rows under expanded headers; `GetSkillLineInfo` returns `name, isHeader, isExpanded, rank`. A collapsed "Professions" or "Secondary Skills" header hides those ranks. `ExpandSkillHeader(i)` and `CollapseSkillHeader(i)` change the list at once. KeepThat expands the collapsed headers from the bottom up, reads the ranks, and collapses the same headers from the top down, as Armory-Classic's `SetExpandableListValues` does. Headers are collapsed again by name, so one failed collapse cannot shift the others. This fires `SKILL_LINES_CHANGED`, so on that event KeepThat reads only the visible rows (no expanding) and refreshes only when a visible rank changed; a rank-up under a collapsed header is picked up from `CHAT_MSG_SKILL`, which triggers a full read and refreshes only when a profession rank changed. Unverified in game: test plan check 9.1.

## Baganator, Bagnon

Not yet probed. Only one bag addon can be enabled at a time.

## Local presentation contract v1 (2026-11-15)

Source inspected inside this repository: bundled AceGUI `AceGUIWidget-Button.lua` uses `UIPanelButtonTemplate`; `AceGUIContainer-Frame.lua` uses the same native button template and `GameFontNormal`; `AceGUIWidget-Label.lua` uses `GameFontHighlightSmall`. AceConfigRegistry's real validator is exercised by `tests/test_smoke.lua` for both TOCs. Appearance uses existing AceConfig toggle/range/color/execute controls, not a new renderer. The Move frame uses those native button templates. Tooltip samples use a private `GameTooltipTemplate`, leaving GameTooltip, third-party rows and native tooltip chrome alone. No Blizzard checkout or live client was inspected during this repository-only implementation; template rendering and client compatibility still require the manual checks below.

Custom toast geometry uses a 4-unit base, 8-unit inset, 280×40 minimum and 28-unit icon. Wrapped content grows the frame and stacking uses measured heights. Text uses client font objects, preferring GameFontHighlightSmall and falling back to GameFontNormal when available. Preferred fonts are resolved through Adapter; no fonts or global skins are installed. Missing CreateFrame disables Move with an explanation; creation errors are caught. Keyboard Escape cancels the transaction while other keys propagate. If keyboard propagation is missing, Move fails safely with an explanation; native Done/Cancel controls use the bundled button pattern. StaticPopupDialogs/StaticPopup_Show provide diagnostic-clear confirmation; if absent, diagnostics remain untouched. Missing item icons use 134400. Missing integrations retain existing status explanations and Classic Era restrictions.

### Public settings boundary

`Core/Presentation.lua` owns type, bounds, default, scope, getter, setter and refresh for each key. There were no existing slash numeric limits to reuse: these are the first public numeric settings, and UI ranges read this registry. All six entries use the active AceDB profile; shared Default and character opt-in semantics remain. No new aliases are introduced; legacy `/kt`, find, test, debug, log and probe remain. Pages: home, materials, integrations, appearance, advanced, about. Topics: appearance, diagnostics, domain. Preview kinds: toast, tooltip, tint, copy. Command words, enums and key/page/topic/kind identifiers are case insensitive; find/probe arguments retain their case.

| Public key | Storage | Boundary / default |
| --- | --- | --- |
| toast | toast | on/off boolean; off |
| tooltip | tooltip | on/off boolean; on |
| appearance.toast.background-opacity | toastBackgroundOpacity | integer 0–100 ↔ alpha 0–1; 100 |
| appearance.toast.text-opacity | toastTextOpacity | integer 0–100 ↔ alpha 0–1; 100 |
| appearance.toast.scale | toastScale | integer 50–200 ↔ scale 0.5–2; 100 |
| appearance.toast.locked | toastLocked | on/off boolean; off |

Valid public setters invalidate Context, refresh visible toast/sample state and notify AceConfigRegistry. Locking cancels Move. Migration is run at initialization and profile callbacks; missing new alpha values inherit the exact old toastOpacity, including zero and fractional values. Get does not migrate or write. The old key is retained for compatibility, but no longer multiplies either rendered layer. Reset position touches only toastPosition. Profile changes cancel the old transaction before refreshing. Log reports flattened settings plus contract version, scope, sample count and Move state; clearing removes only diagnostics, not session loot deduplication or integrations.

Lock blocks drag, Move, direct anchor save and Reset position. Unlock explicitly before resetting; reset preserves the other appearance and gameplay values.

Tooltip preview refinement: choose a random item from the active catalog/routes union. Classify it through the plain model with a private hypothetical skill map at the start of its real route, both categories enabled and no integration callbacks. Native SetItemByID (SetHyperlink fallback) provides item content; uncached items show a catalog name and retry on cache arrival. Live and preview share `Tooltip.Draw`, including per-row ink. Only preview supplies a dummy bag count of 12 and a sample-data footer. The private tooltip is excluded from production hooks to prevent duplicate real classifications.

Compact settings sizing: AceConfigDialog `SetDefaultSize` sets the initial standalone window to 600×460 (bundled default was 700×500). Normal Ace flow/scrolling and user resizing remain available. Appearance sliders and longer action buttons use 1.5 standard control widths; tint-location checkboxes use half width so the three short labels share a row. This uses the bundled AceConfigDialog width contract and does not change Blizzard’s host settings window or any shared library. CVN dimensions were not measured in this repository-only pass.

## Cross-character stock: how Syndicator reads bags, bank and mail (read 2026-11-16)

Source review of Syndicator (`Core/Constants.lua`, `Tracking/BagCache.lua`, `Tracking/MailCache.lua`). Nothing here was probed in game; check it in the test plan. Paths below are relative to `Syndicator/`.

- **Era bank range:** `BANK_CONTAINER` (`Enum.BagIndex.Bank`) plus `NUM_BAG_SLOTS + 1 .. NUM_BAG_SLOTS + 6`, with a comment that the enum has the wrong bank bag values, so it uses the offset instead (Constants.lua:89-96; 6 bank bags on Era, lines 84-85). Backpack through bag 4 (lines 7-13). Syndicator also lists the keyring (lines 81-82); KeepThat does not.
- **Forever bank:** character bank tabs. `Enum.BagIndex.CharacterBankTab_1..9` as the bank list (Constants.lua:56-65), the reagent bag added to the bags (line 53). Tab details come from `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)` (BagCache.lua:255). Syndicator reads a fixed nine-ID list; KeepThat takes the bag IDs the call returns (each entry's `.ID`), falling back to the enum, and chooses the path by those two APIs existing.
- **Events:**
  - `BAG_UPDATE(bagID)`: a bag queues always; a bank ID queues only while `bankOpen` (BagCache.lua:103-109).
  - `PLAYERBANKSLOTS_CHANGED`: on the tabs path the argument is a tab index, mapped to a bag ID through the bank list, while `bankOpen` (lines 115-121). On the classic path it queues `BANK_CONTAINER` while `bankOpen` (lines 122-125).
  - `BAG_CONTAINER_UPDATE` re-reads the bag list (line 127-133); `PLAYERBANKBAGSLOTS_CHANGED` registers only off the tabs path (lines 62-71, 135); `BANK_TABS_CHANGED` and `BANK_TAB_SETTINGS_UPDATED` rescan tabs while the bank is open (lines 138-149).
  - `BANKFRAME_OPENED` sets `bankOpen` and queues every bank ID; `BANKFRAME_CLOSED` clears it (lines 160-176). Queued work runs on the next `OnUpdate`, and the bank loop checks `bankOpen` again when it runs (line 451, classic path).
- **Reading a container:** `C_Container.GetContainerNumSlots`, then `C_Container.GetContainerItemInfo(bag, slot)` taking `.itemID` and `.stackCount` (BagCache.lua:36-46, 409-457).
- **Mail:** `MAIL_INBOX_UPDATE` defers a full rescan to the next frame (MailCache.lua:52, 153-154, 175-218). It replaces the whole record with `GetInboxNumItems()` mails, each with `GetInboxHeaderInfo(i)` and `ATTACHMENTS_MAX` calls of `GetInboxItem(i, a)`. That returns name, itemID, texture, count, quality, canUse (line 31); an attachment counts only when itemID is non-nil (lines 32, 197-198). It does not use the header's `hasItem`, ignores COD, and does nothing about mail beyond the 50 the inbox lists.
- **KeepThat uses:** `GetInboxNumItems`, `GetInboxHeaderInfo` (non-nil header; 8th return `hasItem`), `GetInboxItem` (name, itemID, count), `GetInboxItemLink` (itemID fallback), `ATTACHMENTS_MAX_RECEIVE or ATTACHMENTS_MAX or 16`; `C_Bank.FetchPurchasedBankTabData`, `Enum.BagIndex.CharacterBankTab_N`, `NUM_BAG_SLOTS`, `NUM_BANKBAGSLOTS`, `NUM_TOTAL_EQUIPPED_BAG_SLOTS`, `REAGENTBANK_CONTAINER`; `C_Container.GetContainerNumSlots`, `GetContainerItemInfo`, `GetContainerItemID` (legacy globals as fallback); `UnitFullName`, `GetNormalizedRealmName`, `GetRealmName`, `RegionalUniqueNamesEnabled`, `UnitNameUnmodified`, `UnitFactionGroup`, `time`, `C_Timer.After`. A mail past the inbox's 50 and COD amounts are not counted, same as Syndicator.

- **Bank tabs without an ID (from 0.4.6):** a `FetchPurchasedBankTabData` entry without a numeric `.ID` takes `Enum.BagIndex.CharacterBankTab_<index>`; with neither, the whole list counts as unread and the saved bank is kept.
- **Changes as a window closes (from 0.4.6):** a bank container or the inbox that changed but was not read before `BANKFRAME_CLOSED`/`MAIL_CLOSED`, or that the game reports (`PLAYERBANKSLOTS_CHANGED`, `BAG_UPDATE` for a bank container, `MAIL_INBOX_UPDATE`) within 10 seconds after, loses its record and counts as not counted until the next visit. The bank and inbox cannot be read once closed. Whether a normal close fires one of these events is checked in-game (test plan 8.2, 8.3).
- **Stock identity on WoW Forever (from 0.4.5):** `UnitFullName("player")` returns name and surname there, not name and realm (an in-game capture by another project, not measured by KeepThat; [wowwrapped addon-api](https://github.com/realworldbuilder/wowwrapped/blob/main/docs/addon-api.md#names-and-realms)). **Measured 2026-11-20 from the player's Forever saved variables:** `GetNormalizedRealmName()` and `GetRealmName()` give no realm name at login (0.4.5 logged `no player identity` every session), and Syndicator stores the characters under realm `"PvE"`. Forever has no realm names, so from 0.4.6 the stock realm in surname mode is the ruleset, decided as AceDB 40 does (`C_GameRules.IsGameRuleActive` on `Enum.GameRule.HardcoreRuleset`, `RPRuleset`, `PvPRuleset`: "Hardcore", "RP-PvP", "RP", "PvP", else "PvE"). Without `C_GameRules` it falls back to `GetNormalizedRealmName()`, then `GetRealmName()` without spaces. `UnitFullName`'s second return is used only when surnames are off. When `RegionalUniqueNamesEnabled()` is true and `UnitNameUnmodified("player")` gives a surname (AceDB 40's rule), the character is `"Name Surname"`. Up to 0.4.4 a Forever character was filed as `realms[surname][faction][name]`; its next login moves that record to `realms[ruleset][faction]["Name Surname"]` when that slot is empty.

## Loot toast sounds (read 2026-11-18)

Game sound kits played by ID through `PlaySound(id, channel)` (`Model/Sounds.lua`). Each ID has a `SoundKitEntry` row on both clients (wago.tools DB2, Era build 1.15.9.70576 and Forever build 1.60.1.70938); file names come from the community listfile. KeepThat ships no sound files. Level up, both bell tolls and others have no `SOUNDKIT` constant on Era, so they are played by number.

| Label | Kit | File | Length |
|---|---|---|---|
| Auction open (default) | 5274 | sound/interface/auctionwindowopen.ogg | 2.24 s |
| Level up | 888 | sound/spells/levelup.ogg | 4.36 s |
| Quest complete | 878 | sound/interface/iquestcomplete.ogg | 8.35 s |
| Ready check | 8960 | sound/interface/readycheck.ogg | 2.90 s |
| Raid warning | 8959 | sound/interface/raidwarning.ogg | 1.29 s |
| PvP queue ready | 8459 | sound/spells/pvpthroughqueue.ogg | 5.10 s |
| Murloc aggro | 416 | sound/creature/murloc/mmurlocaggroold.ogg | 1.75 s |
| Bell toll (Alliance) | 6594 | sound/doodad/belltollalliance.ogg | 1.81 s |
| Bell toll (Horde) | 6595 | sound/doodad/belltollhorde.ogg | 2.92 s |
| Battle.net toast | 18019 | sound/interface/ui_bnettoast.ogg | 1.03 s |

- Not usable: `UI_EPICLOOT_TOAST` (31578) is listed in Era's `SoundKitConstants.lua` but has no `SoundKitEntry` row on Era, so it is silent there.
- `PlaySound` and `PlaySoundFile` return `willPlay`; KeepThat treats only `false` as "did not play" (as Don't Do That does) and then falls back to the default.
- LibSharedMedia-3.0 (when another addon provides it): read only with `LibStub("LibSharedMedia-3.0", true)` and `:HashTable("sound")` (name to path, the library's own "None" entry skipped), in `Core/Adapter_Sound.lua`.
- In game (2026-11-18, Era and Forever): the player reported the test plan checks for the toast sound working.

## AceDB character keys (read 2026-11-18)

KeepThat ships AceDB-3.0 minor 40 from 0.4.3 (Ace3 commit `ac3d122`; earlier releases shipped minor 33). LibStub loads the newest minor any installed addon ships, so the key depends on the other addons too.

- **Minor 33:** `charKey = UnitName("player") .. " - " .. GetRealmName()` on every client.
- **Minor 40, Classic Era** (`RegionalUniqueNamesEnabled` missing or false): `UnitNameUnmodified("player") .. " - " .. GetRealmName()`, the same as 33 for normal names.
- **Minor 40, WoW Forever** (`RegionalUniqueNamesEnabled()` true): `name .. " " .. surname` from `UnitNameUnmodified("player")`; `realmKey` becomes the ruleset ("PvE", "PvP", "RP", "RP-PvP", "Hardcore"). `initdb` writes `sv.profileKeys[charKey]` at once, and `SetProfile` raises an error for names that are empty, longer than 50 characters or only spaces.
- **What KeepThat stores per character in AceDB:** only the profile choice (`profileKeys`). Settings live in `profile`, the log and stock in `global`; stock is keyed by `Adapter.PlayerIdentity()`, not by AceDB keys. `db.char`, `db.realm` and the other keyed sections are unused, so the new `realmKey` has no effect.
- **Migration** (`Model/ProfileKey.lua`): at load, a choice saved under the minor-33 key (`Adapter.LegacyCharacterKey()`) is applied once when the character is on Default under the new key and the profile still exists, then the old entry is cleared. From 0.4.4, `ProfileKey.Rename` then moves a profile named after the old key to the new key (switch, `CopyProfile`, `DeleteProfile` when active; a plain table move when not), only when no profile exists under the new key and no other character's choice still names the old profile (from 0.4.5: two Forever characters with one first name on one realm share the old key).

## Recipe knowledge and difficulty (wow-api source review and WoW Forever probe, 2026-11-21)

Classic Era recording is off in 0.5.0 (`Adapter.WINDOW_ROWS_VERIFIED = false`) because no Era test character has Tailoring or Enchanting. The Era entries below come from source review only.


From the generated API docs and Blizzard UI source on wow-api: classic_era 1.15.9.70576 and forever 1.60.1.71037.

- **Classic Era trade skills** (Blizzard_TradeSkillUI/Vanilla):
  - `GetTradeSkillLine()` returns name, rank and max rank.
  - `GetNumTradeSkills()`.
  - `GetTradeSkillInfo(i)` returns name, skillType (`header`, `optimal`, `medium`, `easy`, `trivial`), numAvailable and isExpanded.
  - `GetTradeSkillRecipeLink(i)`.
  - Filters: `GetTradeSkillSubClassFilter(i)` and `GetTradeSkillInvSlotFilter(i)` return 1 when on, and index 0 is "all".
  - No name filter or "Have materials" function was found in the Vanilla source. KeepThat still checks `TradeSkillFrameAvailableFilterCheckButton` if that frame exists.
- **Classic Era Enchanting** uses the craft window (Blizzard_CraftUI/Vanilla):
  - `GetCraftDisplaySkillLine()`, `GetNumCrafts()`.
  - `GetCraftInfo(i)` returns name, subSpellName, craftType, numAvailable and isExpanded.
  - `GetCraftItemLink(i)`. Vanilla has **no `GetCraftRecipeLink`**; only the TBC folder uses it.
  - Open question: does `GetCraftItemLink` carry `enchant:<spellID>`?
- **WoW Forever:**
  - `C_TradeSkillUI.GetBaseProfessionInfo()` returns `ProfessionInfo`.
  - `C_TradeSkillUI.GetRecipeInfo(spellID)` returns `TradeSkillRecipeInfo` with `learned`, `relativeDifficulty` (0 optimal to 3 trivial), `maxTrivialLevel` and `skillLineAbilityID`.
  - Blizzard's own list uses the undocumented `C_TradeSkillUI.GetFilteredRecipeIDs()`. KeepThat asks `GetRecipeInfo` for each catalog recipe of the open profession instead, so the window's filters do not matter.
  - Open question: does `GetRecipeInfo` answer with the window closed?
- **Learn events:** `NEW_RECIPE_LEARNED(recipeID, recipeLevel, baseRecipeID)` exists on both clients. No "You have learned how to create" global string was found in the Classic Era source.
- **`IsPlayerSpell`** is not in the generated docs. Whether it reports recipes is what the probe measures.
- **SkillLineAbility thresholds** (cached CSVs; both clients agree unless noted):

  | Recipe | Yellow (TrivialLow) | Gray (TrivialHigh) | Note |
  | --- | --- | --- | --- |
  | Linen Bandage | 30 | 60 | Wowhead: 1 / 30 / 45 / 60 |
  | Transmute: Arcanite | 275 | 290 | |
  | Mooncloth | 290 / 270 | 320 / 300 | Era / Forever |

  - `MinSkillLineRank` is 1 for many trainer recipes (Silk Bandage, Mooncloth), so the required skill is not in the data.
  - 59 of 1631 profession rows have zero or inverted thresholds.
  - The green start (`floor((yellow + gray) / 2)`) is checked by the `recipe probe` log line: `mismatches=` counts recipes whose computed color differs from the client's.

### WoW Forever probe (1.60.1, 2026-11-21; Tailoring 90, Enchanting 22, First Aid 1)

- **Colors match.** Every recipe at or above yellow had the client's color (Tailoring: 67 of 67, the exact count with yellow at or below 90). First Aid's one learned recipe, below yellow at rank 1, is orange on both sides. The only differences are recipes that are not learned and below yellow: the client says orange (`relativeDifficulty` 0), and KeepThat shows no color there by design. The probe no longer counts these as mismatches.
- **`GetRecipeInfo(spellID)` answers for every catalog recipe of the open profession** (Tailoring 470, Enchanting 262, First Aid 32 rows), so the read is never filtered.
- **The first read after the window opens is stale.** At `TRADE_SKILL_SHOW`, `learned` is false for every recipe and `relativeDifficulty` is 0. The next `TRADE_SKILL_LIST_UPDATE` gives the right values. KeepThat now marks a read incomplete (`stale=` in the probe line) when `IsPlayerSpell` knows a recipe that `GetRecipeInfo` calls unlearned.
- **`IsPlayerSpell(spellID)` is reliable for recipes.** It agreed with the loaded `learned` flag for every row (Tailoring 470 of 470, Enchanting 262, First Aid 32), and was right even during the stale first read.
- **`NEW_RECIPE_LEARNED` carries the recipe's spell ID** when the recipe is learned from a trainer with the window closed (2385). The record updates at once, so the `K.Unsure` fallback stays unwired. `LEARNED_SPELL_IN_TAB` and `LEARNED_SPELL_IN_SKILL_LINE` did not fire.
- Still open: does `GetRecipeInfo` answer with the window closed? This probe read it only with the window open.

## CheckThat (API_VERSION 2; read from CheckThat's `docs/features.md` and `tools/entry_runner.lua`, 2026-11-25)

KeepThat makes every CheckThat call in `KeepThat/Integrations/CheckThat.lua` (Gate key `checkthat`, `anyClient`, no toggle, no Integrations page row). CheckThat is not in `OptionalDeps`: CheckThat lists KeepThat, so KeepThat loads first.

### What CheckThat provides

- `CheckThat.API_VERSION` is 2. Later versions only add.
- `CheckThat.Report(addon, key, value)` records `[addon] key=value` and returns true. It returns false and records nothing when no run is open, an argument is refused or the rate limit drops the fact. It does not raise by design. `addon` is 1 to 32 of `[%w_-]`; `key` is 1 to 48 of `[%w_.-]`; `value` is text up to 120 characters with no control characters, a finite number or a boolean. 30 facts a second per addon; the list (`CheckThatDB.global.facts`) keeps the newest 300 lines.
- `CheckThat.Entry(addon, name, fn)` stores an entry and returns true (name up to 42 of `[%w_-]`). Register at `PLAYER_LOGIN`: CheckThat loads after the addons it lists. A step's `call` runs the entry when the step opens; the outcome is the fact `[KeepThat] entry.<name>=<returns joined by commas>`, or `(none)` for no returns, `threw: <text>`, `not registered`, `refused: in combat`. A fact reported before a step opened does not count for that step.
- Version encoding: `major*10000 + minor*100 + patch` (CheckThat 0.17.0 is 1700; KeepThat 0.7.0 is 700).
- Lua errors while a run is open: `CheckThatDB.global.errors` (strings, quiet, 100 lines).

### How KeepThat uses it

- `ns.CheckThat.Report(key, value)` is a no-op unless the integration is active and `CheckThat.Report` exists. A false return is normal. An error raised inside the call turns the integration off for the session (`[checkthat] FAILED: Report: <error>` in `/kt log`) and no later call is made. An error from `CheckThat.Entry` does the same (`FAILED: Entry: ...`).
- Entries register on an AceAddon module of their own (`CheckThat`), at `PLAYER_LOGIN`, or at once when the Gate starts the integration after login (`ns.Adapter.LoggedIn()`). Log: `[checkthat] started` (the Gate), then `[checkthat] entries registered: <n>`.
- Each entry body runs in `pcall`. An error records `[checkthat] FAILED: entry <name>: <message>` and returns `error: <message>` cut to 100 characters; it does not turn the integration off. No entry writes saved variables, and no result holds a character name.

### Entries

| Entry | Args | Returns | Nothing when |
| --- | --- | --- | --- |
| `version` | none | the KeepThat version as one number (0.7.0 is 700) | the version is unknown or does not parse (`ns.version` from the TOC metadata) |
| `classify` | itemID | `<category>:<profession>` joined with `;`, endgame first, such as `endgame:blacksmithing;endgame:engineering` (current settings and skills) | the item is unmarked |
| `needed` | itemID, profession | the count still needed (the high end of the range) | no route gives a count |
| `exportCount` | profession, category | the number of materials the export would list, then the list name (`KeepThat: Tailoring Leveling`); writes no list | Auctionator support is not loaded |
| `setting` | public key (`/kt help appearance`) | the value `/kt get` prints (`on`, `off`, a number) | the key is unknown |
| `integration` | Gate key | `working`, or the Gate reason (`not detected`, `off`, `not on Classic Era`, `not started`, `failed: ...`) | no Gate |
| `stockCounted` | none | true when this character's bank and mailbox are both counted, false when one is not | stock is unknown |

### Facts

| Key | Value | Written |
| --- | --- | --- |
| `toast.seq` | number, 1, 2, 3, ... per toast shown this session | `Toast.Handle`, when a toast is shown |
| `export.items` | number of searches written | `Auctionator.Export`, after the list is written |
| `estimate.copper` | number, the estimate in copper | `Auctionator.EstimateLines`, only when the estimate summary changes |
| `pj.listed` | number of Profession Journal materials listed (0 when off) | the Profession Journal toggle, next to its `on`/`off` line |

### Debug lines the plan checks

Wording is fixed: a reword is a plan change (`plans/keepthat.yaml`). `ct lines plans/keepthat.yaml --addon-src KeepThat` fails when the source no longer writes a line or fact key the plan asserts.

| Line | Written | Plan step |
| --- | --- | --- |
| `[tooltip] line added <itemID> via <path>` (`postcall` or `settitem`) | once per item and path per session | kt.s2.1, s2.3, s2.4 (diagnostic) |
| `[tooltip] line skipped <itemID>: already on this tooltip` | once per item per session | kt.s2.2 (diagnostic) |
| `[toast] shown <itemID>` | a toast is shown | kt.s3.1 |
| `[toast] skipped <itemID>: shown this session` | once per item per session | none |
| `[toast] sound <name> on <channel>` | the saved sound played | kt.s3.3 |
| `[toast] sound <name> unavailable; played the default` | the saved sound is gone, the default played | none |
| `[toast] move started`, `[toast] move done at <point> <x> <y>`, `[toast] move cancelled` | Move mode on Appearance; a move in combat is allowed today and writes no other line | kt.s6.4 |
| `[merchant] tinted <n> of <m> on page <p>`, `[merchant] tinted <n> of <m> on buyback` | once per page shown (a repaint with the same page and counts writes nothing; closing the vendor resets it) | kt.s4.2, s4.3 |
| `[auctionator] export <profession> <category>: <n> items` | after the list is written | kt.s5.1 |
| `[auctionator] estimate on`, `[auctionator] estimate off` | the "Estimate leveling cost" toggle; each resets the last estimate line so the next page draw writes it again | kt.s5.3 |
| `[options] opened <page>` | `Options.Open` | kt.s6.1 |
| `[options] launcher closed the game's Options and opened <page>` | the Open KeepThat button in the game's Options | kt.s6.2 |
| `[demo] started: toasts=<n> tooltip=<bool> tint=<bool>`, `[demo] ended` | `/kt demo`; `ended` when the tint sample hides (only when the tint showed) | kt.s7.1 |
| `[stock] bank counted: <n> materials`, `[stock] mailbox counted: <n> materials` | a bank or inbox reading replaced the record; n is the number of tracked materials in it; once per visit unless n changes | kt.s8.1 |
| `[checkthat] entries registered: <n>` | the entries were registered | kt.s1.1 (diagnostic) |

### Fake client limits (installed CheckThat skills 0.20.1, 2026-11-25)

- `ct offline` follows `embeds.xml` and accepts `covers:`: AceAddon, AceDB and the Gate start, and the plan's 7 offline steps pass as written.
- `ct offline` reads `offline.toc` inside `--addons`, by default the folder above this repository, so the plan names `wow-keepthat/KeepThat/KeepThat_Vanilla.toc`. A clone in another folder needs `--addons` or a matching folder name.
- The fake client has no TOC metadata, so the `version` entry returns nothing there.
- `ct replay-flow` needs no hooks file: it writes the lines and facts each step expects itself ("evidence assumed": 21 checks on Forever, 14 on Classic Era). It proves the plan flow, not that KeepThat writes them; `ct lines --addon-src KeepThat` proves that (25 found, 0 missing).
