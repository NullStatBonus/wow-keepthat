# Test plan

Manual in-game checks. Run each section on WoW Forever and on Classic Era unless it says otherwise. Section numbers are unique and in order; add new checks at the end of their section.

## 1. Setup

1. Copy `KeepThat/` into `Interface/AddOns/` on the client being tested.
2. Log in. No Lua errors appear (use BugSack or `/console scriptErrors 1`).
3. Type `/kt probe` and keep the report in `debug.txt` (never committed).

## 2. Tooltip line

Run every check on **both clients**: Classic Era (TOC 11509, the `OnTooltipSetItem` path) and WoW Forever (TOC 16001, the `TooltipDataProcessor` path). Start from the default settings unless a check says otherwise. Have Blacksmithing on the character for the leveling checks.

1. **Endgame item.** Hover Arcanite Bar in your bags. The tooltip has exactly one line from KeepThat, `KeepThat: Endgame: Blacksmithing (Shift)`, in purple.
2. **Unmarked item.** Hover an item that is not marked, such as a grey vendor item or Hearthstone. The tooltip has no line from KeepThat.
3. **Tooltip line off.** Clear "Tooltip line" in the settings, then hover Arcanite Bar and Thorium Bar. Neither tooltip has a KeepThat line. Turn the setting back on without a reload, and the line comes back on the next hover.
4. **Two professions.** Hover an endgame material used by exactly two professions (look one up in `KeepThat/Data`; Essence of Earth is a likely candidate). The line reads `Endgame: Alchemy, Blacksmithing`, with the names in alphabetical order.
5. **Many professions.** Hover an endgame material used by four or more professions (look one up in `KeepThat/Data`). The line names two professions and ends with `+N`, where N is the number of other professions.
6. **Both categories.** Turn on leveling marks, with Blacksmithing in the range where Thorium Bar is a leveling material. Hover Thorium Bar. The line reads `Endgame + Leveling: Blacksmithing` in the endgame (purple) color, not green.
7. **Shift on an endgame item.** Hover Arcanite Bar, then hold Shift without moving the mouse. Lines appear below the KeepThat line that name the endgame recipes that use it, each with its quantity (`<Recipe> x<n>`), in grey, with `and N more recipes` when there are more than three.
8. **Shift on a leveling item.** With leveling marks on, hover a leveling material that has a known count, such as Runecloth for Tailoring in the 260-280 range, and hold Shift. A green line like `Tailoring 260-280: 40 needed, 12 in bags` appears, where the bag count matches your bags. For a material where the guides differ, the count reads as a range (`40-55 needed`), and a grey `Guides:` line names them.
9. **Shift on a material used to make another.** Hover Thorium Ore and hold Shift. The details say `Blacksmithing: used to make Thorium Bar for Arcanite Bar` (or the matching text for its profession).
10. **Shift released.** With the details showing (check 7), release Shift without moving the mouse. The tooltip goes back to the single KeepThat line. Press and release Shift several times: the line never shows twice, and the details never pile up.
11. **Chat link.** Link Arcanite Bar in chat (Shift-click it into the chat box and send it), then click the link. The item link tooltip shows `Endgame: Blacksmithing` exactly once. Click the link a second time, then hold and release Shift: still only one line.
12. **Works wherever item tooltips appear.** Hover a marked material in each of these places, and check that the KeepThat line shows exactly once, with the right text and color:
    1. Bags.
    2. Bank.
    3. Merchant window (a vendor that sells a marked material, or the buyback tab).
    4. Auction house browse results.
    5. Loot window.
    6. Mail attachments in the inbox.
    7. Trade window, for both your side and the other player's side.
    8. Recipe reagents in the profession window (for example the reagents of a Blacksmithing recipe that uses Thorium Bar).
    9. Comparison tooltips: hover a marked item with Shift held so the comparison tooltips show, and check that each tooltip shows at most one line.
13. **No Lua errors.** Run checks 1 to 12 with Lua errors shown (`/console scriptErrors 1`). No error appears, and `/kt log` lists no `tooltip` failure.

## 3. Loot toast

1. Default off: on a fresh profile ("Loot toast" unchecked), loot a marked material such as Arcanite Bar or Thorium Ore. No toast appears.
2. Turn on "Loot toast", loot a marked material. A toast appears with the item icon, "<name> x<count>", and the same recommendation as the tooltip, with neutral title and only category words colored, and fades after about 4 seconds without any click.
3. Loot an unmarked item (for example Linen Cloth with leveling marks off). No toast appears.
4. Craft an item, or receive a quest reward that is a marked material ("You receive item:" message). No toast appears.
5. Loot 3 of a marked item, then within a few seconds loot 2 more. The same toast changes from x3 to x5 and no second toast appears.
6. After the toast has faded, loot more of the same item in the same session. No toast appears.
7. /reload, then loot the same item. A toast appears again.
8. Click through a toast onto the game world (or target something behind it). The toast does not take the click.
9. Loot five different marked items at once (for example from several corpses or a mining run). At most three toasts show: the newest at the saved position, older ones above it. The others show as earlier ones fade.
10. Set the leveling and endgame colors to different values and loot one of each. Each toast names its category in that category color; both category names appear when applicable.
11. Default sound: with toasts on and default settings, loot a marked material for the first time this session. The auction house opening sound plays once as the toast appears.
12. Loot more of the same item while its toast shows. The count rises and no sound plays.
13. Loot five different marked items at once. One sound plays; none when the fourth and fifth toasts appear later.
14. Appearance > Sound: choose each of the ten sounds in turn, on Classic Era and on WoW Forever. Each plays once when chosen and matches its name. Choose None and loot a new marked item: the toast shows silently.
15. Sound channel Master: turn off game sound effects (Sound > Enable Sound Effects off), loot a new marked item. The sound is heard. Choose Sound effects and repeat: silent.
16. With an addon that registers LibSharedMedia sounds installed (for example SharedMedia), open the Sound picker: its sounds are listed after the ten as "<name> (sound pack)". Choose one, loot a new marked item, hear it. Disable that addon and /reload: the picker shows Auction open, a new toast plays Auction open, and no Lua error appears. Re-enable it: the saved pack is chosen again.
17. With "Loot toast" off, select Preview loot toast, /kt test toast and /kt demo. Each plays the chosen sound once. The Sound and Sound channel dropdowns are disabled while the toast is off.
18. /kt log lists toastSound and toastSoundChannel under Settings and "sound packs = <count>" (or "none") under Presentation.
19. Motion: loot one marked item, then another a second later. The new toast appears at the saved position and the first glides up (no jump). Each fades in, then fades out over its last second and a half. When the top toast fades away, the ones below it stay put. Move a toast near the top of the screen with Move and check the stack stays on screen with /kt demo.

## 4. Icon mask

Give the section a free number when merging. In each check, "the mask on" means `/kt` > Icon mask is checked. Unless a check says otherwise, keep "Show marks in" at its defaults.

1. **Default settings** (scenario "Default settings"): reset the profile and open your bags with Arcanite Bar in them. No icon is tinted. Do this on both clients.
2. **Endgame item in bags** (scenario "Endgame item in bags"): turn the mask on and open your bags with Arcanite Bar in them. Its icon is purple, and its stack count and quality border are readable. Repeat in Blizzard's bags on Classic Era and on Forever, including the combined-bags view.
3. **Leveling and both** (requirement "Tint marked item icons"):
   - Turn on Leveling. A leveling-only material shows green.
   - A material that is both endgame and leveling shows purple.
4. **Custom color** (scenario "Custom color"): with bags open and tinted, set the endgame color to orange. The tinted icons switch to orange at once, with no reload. Set it back.
5. **Item moved or sold** (scenario "Item moved or sold"):
   - Drag the Arcanite Bar to an empty slot. The old slot loses its tint and the new slot gains it.
   - Sell it to a vendor. No slot keeps a stale tint.
   - Swap it with an unmarked item. The marked item's new slot is tinted, and the unmarked item is not.
6. **Bank** (requirement "Locations chosen by the player"):
   - Open the bank with a marked item in a bank slot and in a bank bag. Both are tinted.
   - Uncheck Bank in "Show marks in". Bank icons lose the tint and bag icons keep it. Check Bank again.
   - Do this on both clients. Forever's bank path is unverified (see the contracts notes).
7. **Location off** (scenario "Location off"): uncheck Merchant and open a vendor with marked materials for sale. The merchant icons show no overlay. Check Merchant again.
   - **Material sold at a merchant** (scenario "Material sold at a merchant"): with Merchant checked, open a vendor that sells a marked material (a trade supplies vendor selling Crystal Vial or Leaded Vial with leveling on). That icon is tinted; turn to the merchant's next page and the tint follows the items.
   - **Material sold by mistake** (scenario "Material sold by mistake"): sell a marked material, open the Buyback tab. Its icon is tinted. Buy it back; the slot clears.
8. **Mask off**: with tinted bags open, turn the mask off. Every tint disappears at once. Turn it on again and the tints return.
9. **Baganator installed** (scenario "Baganator installed"): on Forever, with Baganator as the only bag addon and the mask on:
   - Its bag view shows the tint.
   - Its bank view shows the tint.
   - Its view of another character's bags shows the tint.
   - The Integrations page says Baganator is detected and working.
10. **Bagnon** (requirement "Supported bag interfaces"): on Forever, with Bagnon as the only bag addon, check the bags, the bank and the offline view of another character. Marked items are tinted.
11. **EllesmereUI Bags** (requirement "Supported bag interfaces"): on Forever, with EllesmereUI Bags, check:
    - the bags in grid view and in list view;
    - the reagent bag;
    - the bank.

    Marked items are tinted, and empty or placeholder slots are not. Change the endgame color: EllesmereUI's icons update.
12. **Integration turned off** (scenario "Integration turned off"):
    - Turn off the Bagnon toggle. Bagnon shows no tint, and the status says turned off.
    - Re-enable Bagnon, switch to Baganator, and turn off only Bagnon. Baganator still shows its tint.
    - Turn Bagnon back on. Its tint returns without a reload.
13. **Unexpected bag addon version** (scenario "Unexpected bag addon version"): in a test copy of EllesmereUI Bags, rename `btn._textOverlay` in `EUI_Bags_Slots.lua` (or run any build where it is missing), reload and open the bags. Check that:
    - EllesmereUI Bags works normally without tints;
    - no Lua error appears, with `/console scriptErrors 1` on;
    - `/kt log` names "ellesmereui" and the reason;
    - the Integrations page shows it as failed.
14. **Bag addon on Classic Era** (settings, "Bag addon on Classic Era"): on Classic Era, with Baganator (or Bagnon) installed and the mask on:
    - Baganator shows no tint.
    - Turn the bag addon off, and Blizzard's bags show the tint.
    - The Integrations page says integrations are not yet available on Classic Era.
15. **Debug report** (settings, "Report after an integration failure"): after check 13, `/kt log` lists:
    - every integration with its state;
    - the Blizzard hook paths that were installed (for example `blizzard: hooked ContainerFrame:UpdateItems, BankPanelItemButtonMixin:Refresh`).

    Record these paths in `docs/contracts.md` for each client.

## 5. Auctionator and Profession Journal

All on WoW Forever with debugging on (`/kt debug`) unless a check says otherwise.

### Auctionator export (auctionator-export)

1. Export leveling materials: with Auctionator loaded and Tailoring known, export Tailoring leveling materials. Auctionator's Shopping tab has a list "KeepThat: Tailoring Leveling" with one exact search per Tailoring leveling material still needed from your skill (spot-check against the tooltips' "Leveling:" lines), and searches with a count show a quantity.
2. Export endgame materials: export Blacksmithing endgame materials. The list "KeepThat: Blacksmithing Endgame" has one search per enabled Blacksmithing endgame material (for example Arcanite Bar, Thorium Bar).
3. Turned-off material: turn off one Blacksmithing endgame material in the material list, export again. That material is no longer in the list.
4. Already carrying enough: note the count a Tailoring material's tooltip asks you to keep (for example Bolt of Runecloth), carry that many, export Tailoring leveling. That material is not in the list. Carry one fewer and export again: it is there with quantity 1.
5. Export twice: create a list of your own in Auctionator, export Tailoring leveling twice (change what you carry in between). There is one "KeepThat: Tailoring Leveling" list, reflecting the second export, and your own list is unchanged.
6. Auctionator missing: disable Auctionator and /reload. The export control is disabled and says "Auctionator is needed.". No Lua error.
7. Integration off: turn off Auctionator on the Integrations page. The export control is disabled with a reason. No Lua error.

### Profession Journal as a leveling source (leveling-guidance, "Profession Journal adds to the sources when installed")

8. Installed: with DFL Profession Journal loaded and leveling marks on, hover a Tailoring material its route uses (for example Bolt of Runecloth) and hold Shift. The details list "DFL Profession Journal" among the sources.
9. Profession Journal needs more: find a material where Profession Journal's route (in its own window, from your current skill) needs more than the built-in guides. The top of the tooltip's range equals Profession Journal's count, and the details name Profession Journal.
10. Only in Profession Journal: a material its route uses that no built-in guide uses for that profession is marked as a leveling material for that profession.
11. Nothing saved: after a session with Profession Journal, `KeepThatDB` in `WTF/Account/<account>/SavedVariables/KeepThat.lua` contains none of its route data.
12. Profession Journal unreadable: with Profession Journal loaded, run `/run DFLProfessionJournalNS.GuideData.tailoring.steps = "x"`, then change any KeepThat setting (so the context is rebuilt) and hover a Tailoring material. Only the built-in guides are named, no error is shown, and `/kt log` has a line for professionjournal saying why. /reload afterwards.
13. Profession Journal missing: disable it and /reload. Leveling marks and counts come from the built-in guides only. No Lua error.
14. Integration off: turn off Profession Journal on the Integrations page and /reload. The details no longer name it.
15. Classic Era: on Classic Era with either addon installed, neither integration runs (the Integrations page says integrations are not yet available there). No Lua error.

## 6. Settings and commands

1. Type `/kt`. The KeepThat settings open on the Home page. Options > AddOns lists KeepThat with Materials (an Open KeepThat launcher), Integrations, Appearance, Advanced and About beneath it.
2. On a fresh profile (`/run KeepThatDB=nil` then `/reload`), Home shows: endgame on, leveling off, tooltip on, toast off, mask off, "Show the tint in" with Bags, Bank and Merchant checked, and no other locations listed.
3. Turn leveling materials on and hover a leveling material (for example Linen Cloth). The tooltip shows the `Leveling:` line without a reload. Turn it off; the line goes away.
4. On Appearance change the endgame color; the mask or toast color changes on the next refresh. Check each "Show marks in" box once.
5. Open Materials > Blacksmithing > Arcanite Bar (the tree entry has a purple square). The page starts with its icon and name, shows a toggle that is on and the recipes with quantities, and no source line. Click "Copy Wowhead link": a box opens with the link selected; Ctrl+C copies it.
6. Turn the Arcanite Bar toggle off; hover one: no endgame line. `/reload`: still off. Turn it on again.
7. Turn leveling materials off on Home: leveling-only materials (green square only) leave the Materials list. Turn both off: everything is listed with a note that nothing is marked. Search "rune", open Tailoring: "Showing materials matching" and Clear search appear; Clear search shows everything again.
8. Turn Loot toast on; on Appearance choose Move, drag the placeholder and choose Done. Loot a marked item: the toast appears there. Reset position restores the default anchor.
9. On Classic Era open Integrations: it says integrations are not yet available on Classic Era, and Baganator or Bagnon (if installed) show no overlay. On WoW Forever each row shows Not detected, Detected and working, or Detected but turned off with a reason; turning a toggle off stops that integration on the next refresh.
10. On Advanced, turn on "Use separate settings for this character", change a Home setting, log into another character: it keeps the shared settings. Turn the option off: this character returns to the shared settings.
11. `/kt debug on`, hover a few items, `/kt log`: a window opens with the settings, integration states, failures and recorded lines, and Ctrl+A, Ctrl+C copies it. `/kt debug off` stops recording.
12. Type `/kt nonsense`: the command list prints in chat.

13. On Materials, search part of a name in mixed case and press Enter: only matching materials and professions remain. Check a cached client name and its English name, and literal `%` and `.` searches. Search applies across professions. Clear the box: all return.
14. Search for `nonexistentmaterial`: one neutral no-match sentence appears. Reload: the search is empty.
15. `/kt find` on a name with one path opens its material page. `/kt find Arcanite Bar` (Blacksmithing and Engineering) opens Materials with the search set to "Arcanite Bar", only those two professions expanded, and nothing printed in chat. With Endgame materials off on Home, `/kt find Arcanite Bar` says to turn it on and opens nothing. A nonexistent name prints the no-match sentence; `/kt find` prints usage.
16. Open the game's AddOns list (Menu > AddOns): KeepThat shows its round "KEEP THAT!" badge next to its name, on Classic Era and WoW Forever.

## 7. Cohesive presentation acceptance

Run on Classic Era and Forever at the same UI scale with only KeepThat first, then supported optional addons. Enable script errors. Capture Home, Appearance, a real item tooltip, three demo toasts, the tint sample, Move controls and the log-clear confirmation. Record client/build, UI scale, addon scale and installed integrations with captures.

1. Open `/kt` and `/kt settings`; Home opens. Visit Home, Materials, Integrations, Appearance, Advanced and About in order. Verify the window title is KeepThat and scope is explained in the page content. Material search, long item names, quality-colored detail titles, category toggles, stock, recipes, Wowhead copy and shopping exports remain reachable. Check third-party tooltip rows before/after KeepThat and while Shift is held.
2. Set each public key through `/kt set`, check `/kt get` and the already-open UI, then change it in the UI and check get. Try missing values, trailing words, unknown keys/pages/topics/kinds, fractional integers and out-of-range numbers; nothing should change. `/kt help appearance` lists exact bounds and examples. Mixed-case `/kt find ArcANite` retains normal matching.
3. On an upgraded profile with old toastOpacity 0, 0.37 and 0.8, confirm both new alphas preserve effective brightness, colors, enabled flags and anchor. Test a new profile too. With loot toast enabled, test Background opacity and Text and icon opacity separately at 0/80/100. Background 0 must hide black fill AND accent, while text follows its own value. Test already-visible and newly created toasts. Test Scale 100/150 (and supported bounds 50/200).
4. Test very long localized item names and multi-line recommendations. Every title/category/recommendation must remain readable, grow and stack without overlap; missing cached item icon uses a fallback. Native tooltip chrome remains native. Test missing preferred font/control APIs with a test environment or probe; unavailable controls must fail safely and explain the action. Do not remove live game globals in a normal play session.
5. Turn real toasts, tooltip and tint off. Run `/kt demo` twice before expiry: exactly three labeled sample toasts, a private native tooltip for a random real material (Shift expands details using sample skills and bag counts), and isolated tint appear. Toast/tint expire after four seconds, tooltip after fifteen. Use `/kt preview` and each kind; only that surface appears. Verify `/kt test toast`, tooltip and copy still work. While demo runs, loot a real marked item with real toasts enabled: samples must not change counts, classification or deduplication; normal live state resumes after samples. Bag tints and external integrations remain real.
6. Move from Appearance while unlocked: drag to screen edges (clamped), Done saves; repeat and Cancel/Escape restore. Right-click commits. Lock prevents Move and dragging; toggling lock during Move cancels. Reset position retains colors, opacity, scale, lock and material toggles. Switch scope during a drag; neither profile receives the tentative anchor. Verify normal toasts remain mouse-transparent. Repeat in combat and after leaving combat; no protected-action or keyboard errors. Confirm non-Escape keys continue to reach the game while moving.
7. Change shared settings on one character and relog on another. Switch to character scope after reading confirmation; cancel leaves scope unchanged. Switch back and verify both profiles retain independent values. While a preview is open, change appearance/scope and verify it uses current values.
8. Record diagnostics, run `/kt log clear`, cancel/Escape and verify the log remains. Accept and verify only diagnostics/failure history clears: settings, material toggles, saved anchor, loot deduplication and integration session state remain. `/kt log` stays copyable and lists all new settings, contract version, scope, sample count and Move state.

No CV warning/prompt, DDT, sibling-addon ordering or shared library checks apply to KeepThat. Store comparable screenshots as local review artifacts; do not commit them. In-game checks and captures cannot be certified by the plain-Lua harness.

Tooltip preview parity: repeat `/kt preview tooltip` several times. Items must come from the Materials list, with their native quality-colored name and item description when cached. KeepThat’s collapsed hint, Shift details, category colors and gray recipe/guide rows must match a real hover. The footer identifies sample skills/counts. Test an uncached item: the catalog name appears first, then native item content when data arrives. Turning real tooltips or material toggles off must not prevent preview or modify those settings.

Settings context review: open all six top-level pages plus one profession and one item page directly. Each must explain its purpose and next action. Scope guidance appears on Advanced and where it changes a choice; it should not repeat on every page. In Appearance, check section grouping and the separate toast/tooltip/tint preview buttons. Turn features on/off and lock/unlock position: enabling instructions must appear only when relevant. Begin Move and verify the guidance and Done/Cancel states update immediately. Check integration descriptions distinguish permission from actual detection/working status, and that Advanced explains profile switching and the complete record/reproduce/copy workflow. At smaller window sizes and with long translations, text must wrap without obscuring controls.

Compact settings: after reload, `/kt` starts at 600×460. Check that appearance sliders and action buttons do not span the content panel, and Bags/Bank/Merchant fit in a compact row. Resize narrower/wider and verify prose wraps, labels remain complete, all controls remain reachable by scrolling, and material-tree navigation still works. Compare beside CVN at the same UI scale; CVN’s exact dimensions have not been measured here.

## 8. Materials launcher and collapsed professions

Run on WoW Forever and Classic Era, first with only KeepThat enabled.

1. Open Esc > Options > AddOns > KeepThat > Materials. The page shows a short explanation and an **Open KeepThat** button, and no material list.
2. Click Open KeepThat: the game's Options window closes and the KeepThat window opens on Materials.
3. Back in Esc > Options > AddOns > KeepThat, move from Materials to each other KeepThat entry (Home, Integrations, Appearance, Advanced, About): each opens without a noticeable pause.
4. In `/kt`, expand Blacksmithing and Tailoring under Materials, close the window, type `/kt` again and open Materials: every profession is collapsed.
5. `/kt find Arcanite Bar`: Materials opens filtered to it, with only Blacksmithing and Engineering expanded.

## 9. Cross-character stock

Use three characters on the same realm and faction (call them Main, Bankmule and Hunter), each with KeepThat, and Runecloth with leveling marks and Tailoring on Main. Run everything on Classic Era first, then on WoW Forever, where the bank has modern tabs.

1. Log in on Bankmule with 30 Runecloth in its bank; open the bank and the mailbox, then log out. Log in on Hunter with 5 Runecloth in its mailbox; open the bank and the mailbox, then log out.
2. Log in on Main with 12 Runecloth in its bags and 8 in its bank; open the bank and the mailbox. Hover Runecloth: `KeepThat: Leveling: Tailoring - 55 owned (Shift)`.
3. Hold Shift: the need row still reads `40 needed, 12 in bags`, and below the details a `Stock` block shows `This character: 20`, `Bankmule: 30` and `Hunter: 5`, in that order. With more than five characters holding it, five lines show, then a line such as `+3 more`.
4. Open the item's page under Materials > Your stock: `55 owned - 20 on this character, 35 on your other characters`, then `This character: 12 in bags, 8 in the bank`, `Bankmule: 30 in the bank (3 days ago)` and `Hunter: 5 in the mailbox (2 hours ago)`, with the real ages. Check the wording for an item only on this character (`20 owned, all on this character`), only on others (`35 owned, all on your other characters`) and on none (`None on any of your characters.`).
5. Deposit 10 of the item from Main's bags into its bank, then close the bank. The total on the tooltip does not change; the holder line moves 10 from bags to the bank.
6. Open the mailbox on Main, take an attachment into bags, close it: the total stays right, with no double count while the mail is open. On Forever, also move an item between bank tabs and check the total.
7. Log in on a third character (same realm and faction) without opening its bank or mailbox. `/kt status stock` lists it as `<Name>: bank and mailbox not counted.`. Open only the bank: it changes to `<Name>: mailbox not counted.`. Open the mailbox: `Every bank and mailbox is counted.`.
8. On a character with a bank or mailbox not counted, the item page hides "Still to get". Once every bank and mailbox is counted it shows again.
9. Reminder: with a bank or mailbox not counted, log in: one chat line `KeepThat: 2 characters have a bank or mailbox not counted. /kt status stock lists them.` (with the right count). `/reload`: it shows once more. Do it again after completing every bank and mailbox: no line. No raw `|` in the chat text.
10. Turn off Login reminder on Home: log in and `/reload`; no line. Turn it on and run `/kt set stock.reminder off` then `/kt get stock.reminder`: the Home checkbox follows. `/kt set stock.reminder on` restores it. `/kt help stock` explains the commands. `/kt log` lists the setting.
11. Auctionator (WoW Forever): with Auctionator loaded, export a leveling list for a profession on Main. A material the realm-and-faction total already covers is left out, and the others carry only the missing quantity.
12. Put items in the guild bank and the account bank (Forever, if available) and open them: no total, tooltip or `/kt status stock` line changes.
13. Log in on a character of the other faction on the same realm (or another realm): it is not counted in Main's totals, and `/kt status stock` shows only the realm and faction of the character you are on.
14. Rename or delete a character, or leave one unseen for 90 days (set the system date, or check the saved data with `/kt log`): its stock drops out of the totals and `/kt status stock`.

## 10. Library update and Forever profile

1. With KeepThat, Don't Do That and Closest Vendor all installed, on Classic Era and on WoW Forever: open each addon's settings window, `/reload`, visit a merchant. No Lua errors (BugSack or `/console scriptErrors 1`).
2. Forever carry-over: on 0.4.2, turn on Advanced > "This character" on one character and change a setting (for example Scale 150); keep another character shared. Update to 0.4.3 and log in on the first character: "This character" is still on and Scale is still 150. The second character still uses the shared settings.
3. On that first character, turn "This character" off, `/reload`: it uses the shared settings and stays so after another `/reload`.
4. Turn "This character" on again after step 3: the same settings come back (Scale still 150), not defaults.
5. Classic Era: a character with "This character" on keeps its profile and values after the update.
6. Forever, a character that already toggled "This character" off and on under 0.4.3 (so it has both an old-named and a new-named profile): after 0.4.4 it keeps the profile it was using; nothing is overwritten.

## 11. Forever character names

On WoW Forever, with a save used by KeepThat 0.4.4 or earlier: two characters, A and B, on the same realm and faction with different surnames, and A's bank opened once before the update with Runecloth in it.

1. Log in on A: `/kt status stock` names the realm, not A's surname.
2. Log in on B: hold Shift over Runecloth; the `Stock` block lists A by first name and surname with its bank count.
3. On A, turn on Advanced > "This character", set Scale to 150, `/reload`: Scale is still 150.
