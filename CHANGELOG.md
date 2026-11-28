# Changelog

## 0.7.2

- Changed: **WoW Forever leveling counts now follow the current guides.** Before, some counts were too low.
- Changed: The WoW Forever data now matches game build 1.60.1.71139. One new Leatherworking recipe is included.

## 0.7.1

- Changed: **Nothing changes in game.** This release updates the developer files only.

## 0.7.0

- New: **KeepThat works with CheckThat, the in-game test runner.** Nothing changes in game for players.
- New: CheckThat can read the KeepThat version and check many test plan steps by itself.
- Changed: The test plan has a new first step that checks the version. The "No Lua errors" step is now step 1.2.

## 0.6.1

- Changed: **Nothing changes in game.** This release updates the developer files and the test plan only.

## 0.6.0

- New: **Cost estimate for leveling materials.** Turn on "Estimate leveling cost" under Auctionator on the Integrations page.
- New: The estimate shows below "Export leveling list" on each profession page.
- New: Hold Shift over a leveling material to see the cost of the quantity you still need.
- New: The estimate uses the prices from the last Auctionator scan. A missing or old price counts as unknown, not zero.

## 0.5.0

- New: **Hold Shift to see if you know each endgame recipe.** Each recipe line shows "Learned" or "Not learned" and its skill color, such as Yellow.
- New: Open a profession window one time. KeepThat then remembers the recipes of that character.
- New: Learned recipes show first. Use "Recipe order" on Home to change the order.
- New: On Classic Era, recipe lines show the skill color only.

## 0.4.8

- Changed: **Nothing changes in game.** This release updates the developer files and the test plan only.

## 0.4.7

- Fixed: **On Classic Era, leveling counts use your real skill rank.** Before, a collapsed Professions header on the Skills tab made the counts start at skill 1.
- Fixed: A guide with no count for the steps ahead now shows no count. Before, the tooltip said "You have enough." The Auctionator list also left the item out.
- Fixed: When you turn off Profession Journal, its materials go away from Materials, `/kt find`, the leveling counts and Auctionator. Before, they stayed until you reloaded.
- Fixed: The "Includes" shares for intermediates are never more than the count. Before, the shares could add up to more than the count.

## 0.4.6

- On WoW Forever, stock is recorded again (0.4.5 stopped recording it) and shared across your characters on the same ruleset.
- Stock totals no longer count a stack twice when you close the bank or mailbox right after moving it, and Profession Journal materials are counted across your characters.

## 0.4.5

- On WoW Forever, your characters on a realm share their stock again, and a character with the same first name as another no longer takes its settings.

## 0.4.4

- On WoW Forever, turning "This character" off and on again brings back your own settings instead of starting fresh.

## 0.4.3

- On WoW Forever, characters that use their own KeepThat settings keep them after the shared settings library update.
- Updates the bundled settings libraries, which fixes color pickers with transparency on WoW Forever.

## 0.4.2

- Loot toasts rise from their position, newest at the bottom, glide into place and fade in and out gently.

## 0.4.1

- Removes a library KeepThat never used; nothing changes in game.

## 0.4.0

- Loot toasts play a sound you can pick: the auction house sound by default, nine other well-known game sounds, sound packs, or none.

## 0.3.0

- Tooltips, material pages and the Auctionator list count what all your characters on the realm and faction hold, in bags, bank and mailbox, with a login reminder when a bank or mailbox has not been counted yet.

## 0.2.2

- KeepThat shows its badge icon in the game's AddOns list.

## 0.2.1

- Materials in the game's Options window opens the KeepThat window, fixing a long freeze; professions start collapsed, `/kt find` shows its matches in Materials, and the icon tint works with Baganator again.

## 0.2.0

- Customize toast opacity and scale, preview sample visuals, and move toasts with Done or Cancel.

## 0.1.0

- First release: tooltips mark crafting materials worth keeping for endgame and leveling, with optional loot toasts and bag icon tints.
