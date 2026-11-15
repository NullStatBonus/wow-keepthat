# Client and addon contracts

What the game and other addons actually provide, as measured with `/kt probe` (task 1.3). Code picks a path by checking that an API exists (see `CLAUDE.md`), and this file records which path each client takes. Mark an entry "unverified" until a probe has confirmed it.

## WoW Forever (1.60.1, build 70938, interface 16001)

Measured 2026-11-15, with EllesmereUI 9.8.6 (Bags module), Auctionator 347 and DFL Profession Journal 3.16.76 loaded.

### Client APIs

- **Tooltips:** `TooltipDataProcessor.AddTooltipPostCall` and `Enum.TooltipDataType.Item` exist; `GameTooltip` has no `OnTooltipSetItem` script. Use the post-call path (design D5).
- **Items:** the old globals `GetItemInfo`, `GetItemInfoInstant` and `GetItemCount` are **missing**; use `C_Item.*`.
- **Containers:** only `C_Container.*` (47 functions). `ContainerFrame_Update`, `ContainerFrame_UpdateItems` and `BankFrameItemButton_Update` are missing; `ContainerFrameCombinedBags` and `BankFrame` exist. The Blizzard bag integration has to hook the item button mixins or the combined bag frame, not the old update functions.
- **Skills:** `GetNumSkillLines` and `GetSkillLineInfo` are missing; `C_SkillInfo` has `GetNumSkillLines`, `GetSkillLineInfo` and `GetSkillLineInfoByID`. `C_TradeSkillUI` exists (147 functions).
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
  - If no mixin is found, the integration fails with "no Baganator item button mixin with SetItemDetails".

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

Forever's probe showed `BankFrame` but not which of these exists, so check the bank on Forever (test plan check 6).

## Classic Era

Not yet probed.

## Baganator, Bagnon

Not yet probed. Only one bag addon can be enabled at a time.
