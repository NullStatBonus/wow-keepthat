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

### DFL Profession Journal (3.16.76)

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
