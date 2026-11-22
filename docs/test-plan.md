# Test plan

Manual in-game checks, only for what the unit tests cannot prove: real client hooks, drawing, sound, and other addons. Run each section on WoW Forever and on Classic Era unless it says otherwise. Section numbers are unique and in order; add new checks at the end of their section.

Before the checks, type `/kt debug on`, then `/reload`. After them, type `/kt log`, press Ctrl+A and Ctrl+C, and give the reviewer the copied report. Or copy `KeepThat.lua` from `WTF/Account/<account>/SavedVariables` and say where it is. The `Log:` line is for the reviewer. Where a check has no `Log:` line, the result shows only on screen.

## 1. Setup

1. **No Lua errors.** Copy `KeepThat/` into `Interface/AddOns/`, turn on Lua errors (`/console scriptErrors 1`), and log in.
   Check: no error window appears.

## 2. Tooltip line

Run every check on **both clients**: Classic Era (the `OnTooltipSetItem` path) and WoW Forever (the `TooltipDataProcessor` path). Use the default settings. Have Blacksmithing on the character and Arcanite Bar in your bags.

1. **Endgame item.** Hover Arcanite Bar in your bags.
   Check: the tooltip has exactly one KeepThat line. It starts `KeepThat: Endgame:`, names Blacksmithing, and "Endgame" is purple. It can end with how many you own.
2. **Shift details.** Hover Arcanite Bar, then press and release Shift without moving the mouse.
   Check: the recipe details appear while Shift is down and go away when it is up. The KeepThat line never shows twice.
3. **Chat link.** Send Arcanite Bar as a chat link (Shift-click it into the chat box), then click the link.
   Check: the link tooltip has exactly one KeepThat line.
4. **Profession window.** Open the Blacksmithing window and hover a reagent that is a marked material, such as Thorium Bar.
   Check: the reagent tooltip has exactly one KeepThat line.

## 3. Loot toast

Turn on "Loot toast" on Appearance first. Use a marked material you can loot or gather, such as Thorium Ore.

1. **Toast and sound.** Loot a marked material for the first time since the last `/reload`.
   Check: a toast with the item icon and name appears at the saved position, the auction house sound plays once, and the toast fades without a click.
2. **Click-through.** While a toast shows, click a unit behind it.
   Check: the click targets the unit.
3. **Sound pack.** Install an addon that adds LibSharedMedia sounds (for example SharedMedia) and choose one of its sounds on Appearance. Loot a new marked material.
   Check: you hear the chosen sound.

## 4. Icon mask

Turn on the icon mask: `/kt` > Icon mask. Keep "Show marks in" at its defaults.

1. **Blizzard bags and bank.** With Arcanite Bar in your bags and in the bank, and no bag addon installed, open the bank.
   Check: both Arcanite Bar icons are purple, and the stack count and quality border stay readable.
   Log: `[blizzard] hooked ...` with the hooked bag and bank paths (`ContainerFrame_Update` on Classic Era, `ContainerFrame:UpdateItems` on WoW Forever). Record the paths in `docs/contracts.md` for each client.
2. **Merchant.** Turn on leveling marks. Open a trade supplies vendor that sells a marked material, such as Crystal Vial, and turn to the vendor's next page.
   Check: on each page, only the marked materials are tinted.
   Log: `[merchant] hooked ...`.
3. **Buyback.** Sell a marked material to a vendor, then open the Buyback tab.
   Check: its icon is tinted.
4. **Bag addon.** On WoW Forever, with Baganator, Bagnon or EllesmereUI Bags as your bag addon, open its bags.
   Check: marked items are tinted, and empty slots are not.
   Log: `[baganator] started`, `[bagnon] started` or `[ellesmereui] started`, and no `FAILED` line for it.

## 5. Auctionator and Profession Journal

On WoW Forever only, with Tailoring known and leveling marks on.

1. **Auctionator export.** With Auctionator loaded and at least one Tailoring leveling material still needed (its tooltip shows "needed" and you carry fewer), export the Tailoring leveling materials from the Materials page.
   Check: Auctionator's Shopping tab has a list "KeepThat: Tailoring Leveling" that includes that material.
2. **Profession Journal sources.** With DFL Profession Journal loaded, pick a material from a step of its Tailoring route still ahead of your skill (shown in its own window). Hover that material and hold Shift.
   Check: the details list "DFL Profession Journal" among the sources.
3. **Leveling cost estimate.** With Auctionator loaded and a recent scan, turn on "Estimate leveling cost" on the Integrations page. Open Materials, then Tailoring.
   Check: below the export buttons, a gold amount from Auctionator's last scan shows, or "At least" an amount if some prices are missing.
   Log: `[auctionator] estimate tailoring: <copper> copper, <n> priced, <n> unknown`, and `/kt probe` shows "present  GetAuctionPriceByItemID(14047) = <a number>" under "Auctionator prices".
4. **Cost in the tooltip.** With the estimate on, hold Shift over a Tailoring leveling material that you still need.
   Check: the leveling details show "Estimated cost for" a number and an amount below the count, or say no recent price is known.

## 6. Settings window

1. **Open settings.** Type `/kt`.
   Check: the KeepThat window opens on Home.
2. **Options launcher.** Open Esc > Options > AddOns > KeepThat > Materials and click **Open KeepThat**.
   Check: the page shows the Open KeepThat button and no material list. The button closes the game's Options window and opens KeepThat on Materials.
3. **Copy Wowhead link.** Open Materials > Blacksmithing > Arcanite Bar and click "Copy Wowhead link".
   Check: a box opens with the link selected, and Ctrl+C copies it.
4. **Moved toast.** Turn on "Loot toast". On Appearance, click Move, drag the placeholder to a new place, and click Done. Then loot a marked material.
   Check: the toast appears where you dropped the placeholder.
5. **Move in combat.** Start a fight, then click Move on Appearance and drag the placeholder. Press a movement key.
   Check: no error appears, and your character moves.
6. **AddOns list badge.** Open the game's AddOns list (Menu > AddOns).
   Check: KeepThat shows its round "KEEP THAT!" badge next to its name.
7. **Debug report window.** Type `/kt log`, press Ctrl+A, then Ctrl+C.
   Check: a window opens with the report, and Ctrl+C copies it.
   Log: the copied report starts with `KeepThat <version>, client <client>` and lists the settings, the integration states and the failures.

## 7. Cohesive presentation

1. **Demo.** Turn off real toasts, the tooltip and the tint. Type `/kt demo`.
   Check: three labeled sample toasts, a sample item tooltip and a sample tint appear. The toasts and the tint go away after about four seconds.
2. **Settings layout.** Type `/kt` after a `/reload` and open each page.
   Check: the window opens at its compact size, text wraps without covering a control, and every control is reachable by scrolling.

## 8. Cross-character stock

Use WoW Forever and Classic Era. Use a character with Tailoring, leveling marks and the tooltip line on, and Runecloth in its bags, its bank and an unopened letter. Before each check, hover Runecloth and note the `owned` total.

1. **Bank and mailbox are counted.** Open the bank, then the mailbox, then close both and type `/kt status stock`.
   Check: chat does not list this character as not counted.
   Log: under `Stock:` in the report, the `missing =` line does not name this character.
2. **Take from the bank and close at once.** Open the bank, right-click a stack of Runecloth in it, and press Escape in the same moment. Hover Runecloth.
   Check: the `owned` total is the same as before, or lower. It is never higher.
   Log: `[stock] bank changed as it closed; not counted until it is opened again`, when the game reported the move after the close.
3. **Take from the mailbox and close at once.** Open the letter with the Runecloth, click the attachment, and press Escape in the same moment. Hover Runecloth.
   Check: the `owned` total is the same as before, or lower. It is never higher.
   Log: `[stock] mail changed as it closed; not counted until it is opened again`, when the game reported the change after the close.

## 9. Leveling numbers

The reviewer reads each result from its debug log, so there is nothing to look for on screen.

1. **Classic Era, collapsed Skills header.** Use a character with any profession; Cooking or First Aid count. On the Skills tab, collapse the header the profession sits under (**Professions**, or **Secondary Skills** for Cooking and First Aid), then type `/reload`.
   Check: KeepThat reads the real skill rank while the header is collapsed.
   Log: `[skills] cooking=54; collapsed headers: Secondary Skills` (your profession and rank).
2. **WoW Forever with DFL Profession Journal.** On the Integrations page, turn **DFL Profession Journal** off, then on again.
   Check: Profession Journal's materials leave KeepThat's lists when it is off and come back when it is on, with no reload.
   Log: `[professionjournal] off: 0 materials listed`, then `[professionjournal] on: N materials listed (...)` with N above 0.

## 10. Recipe status

WoW Forever only: Classic Era does not record recipe knowledge in this version.

1. **Tailoring recipes.** Use a character with Tailoring, with debug recording on and `/reload` done (see the top of this page). Open the Tailoring window.
   Check: KeepThat remembers your Tailoring recipes.
   Log: `[recipes] tailoring complete=true known=<n>`, and a `[recipes] recipe probe: tailoring ... stale=0 ... mismatches=0` line. The first probe line after the window opens can show `stale=<n>` and mismatches; that read is not recorded.
