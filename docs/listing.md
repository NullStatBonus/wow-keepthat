# Store listing

This page has the text and field values for the CurseForge and Wago projects. The project IDs go in both TOC files (`## X-Curse-Project-ID`, `## X-Wago-ID`) once the projects exist; see [publishing.md](publishing.md). The category names and field limits below come from memory of the site forms. Check them when you fill in the forms. If a name is different, choose the closest match.

## Fields

| Field | Value |
|---|---|
| Project name | KeepThat |
| Slug / URL name | keepthat (use whatever is free) |
| Summary (one line, keep under 250 characters) | KeepThat adds a short tooltip line to the materials worth keeping for endgame crafting or profession leveling, so you never sell what you'll need later, in WoW Forever and Classic Era. |
| Main category | Professions |
| Additional categories | Bags & Inventory, Tooltip |
| Game versions | CurseForge calls Classic Era **Classic**: tick Classic (1.15.x) and Forever (1.60.x). The packager reads `## Interface` from each TOC: 11509 for `KeepThat_Vanilla.toc`, 16001 for `KeepThat_Camelot.toc`. |
| License | MIT |
| Source code URL | `https://github.com/NullStatBonus/wow-keepthat` |
| Issues URL | `https://github.com/NullStatBonus/wow-keepthat/issues` |
| Relations | Optional: Baganator, Bagnon, EllesmereUI, Auctionator, DFL Profession Journal. Nothing is required. The Ace3 libraries are bundled. |
| Tags | professions, crafting, materials, tooltip, bags, inventory, leveling, endgame, auction house, quality of life, classic, forever |
| Release type | Release (use Beta for pre-release tags) |
| Changelog | Taken from `CHANGELOG.md` by the packager; nothing to type. |
| Donations | none |

## Description

Paste this into the description box (CurseForge and Wago both take Markdown or HTML; use the Markdown editor if offered).

---

**Never sell the materials you'll need later.**

KeepThat adds one short line to an item's tooltip when it is a material worth keeping, for endgame crafting or for leveling a profession. It works on WoW Forever and Classic Era, with no other addon needed.

- **Endgame materials.** On by default. A tooltip reads `KeepThat: Endgame: Blacksmithing`, with "Endgame" in purple. Hold Shift to see which recipes use the item and how many each needs.
- **Leveling materials.** Off by default. Turn them on and the tooltip reads `KeepThat: Leveling: Tailoring`, with "Leveling" in green. Hold Shift to see how many to keep.
- **Counts that fit you.** If you know the profession, the count runs from your current skill to 300. When the guides disagree, you see a range, such as `40-55`.
- **Materials made from other materials.** If a bar is made from ore, the ore is marked too, and the tooltip says what it is used to make.
- **Several professions.** One line lists them, with `+N` when there are more than two.
- **Stock across characters.** The tooltip shows what you own on all your characters on the same realm and faction (bags, bank and mailbox), such as `55 owned`; Shift lists each character. Auctionator lists only buy what that total does not cover. The guild bank is never counted.
- **Loot toast.** Off by default. A small pop-up when you loot a marked material, with neutral item names and labeled category colors. It plays a game sound you choose (auction house opening by default, or None). Adjust background and text opacity independently, change scale, preview it, and move its locked or unlocked anchor with Done/Cancel.
- **Icon tint.** Off by default. Colors the icon of marked items in your bags, bank and merchant windows, including the buyback tab.
- **Your choice, item by item.** The Materials page lists every material by profession, with a colored square for endgame or leveling. Turn any one off, and copy its Wowhead links with one click.

**Where the lists come from.** Classic Era uses wow-professions.com and Wowhead. WoW Forever uses Metabot and RankedBoost. If you have DFL Profession Journal, its route counts as one more guide.

**Works with your other addons (WoW Forever only in this version).** Baganator, Bagnon and EllesmereUI Bags show the icon tint. Auctionator can get a shopping list of the materials you still need for one profession. DFL Profession Journal adds its counts. If one is missing or changes, KeepThat turns that part off and keeps working. On Classic Era, these are not available yet.

Search the materials pages by item name, or use `/kt find <name>` to jump to a single match or list matching paths.

**Start:** type `/kt` to open the settings.

**Good to know**

- Counts follow the free guides above. Your own route may need more or less, so a range shows how much the guides agree.
- WoW Forever uses the Classic Era endgame lists for now. They will change as Forever's new content and guides settle.
- Stock counts a character after it logs in once and you open its bank and mailbox there. Only your characters on the same realm and faction are counted. `/kt status stock` lists what is missing.
- Settings are shared by your whole account. You can switch one character to its own settings on the Advanced page.
- If another addon changes and KeepThat can't work with it, KeepThat turns off only that part and says why on the Integrations page.

**Problems?** Type `/kt debug on`, repeat what went wrong, then type `/kt log`. Copy the report and send it with your client (Classic Era or Forever).

Free and open source (MIT). The Ace3 libraries in the addon keep their own license.

---

## Screenshots to capture

1. An endgame tooltip line, and the same item with Shift held.
2. A leveling tooltip with a count and range.
3. Bags with the icon tint on.
4. A material page (Materials > Blacksmithing > Thorium Bar).
5. A loot toast.

## After creating the projects

Put both IDs in both TOC files (`## X-Curse-Project-ID`, `## X-Wago-ID`). With the repository secrets `CF_API_TOKEN` and `WAGO_API_TOKEN` set, every `vX.Y.Z` tag publishes to both sites (see [publishing.md](publishing.md)). Update the pasted description and summary on each site whenever this file changes; the sites do not read it.

## Before each release

1. Check the Game versions row still matches the `## Interface` values in both TOCs.
2. Skim the description against `README.md` and the specs; update both if the features changed.

Use `/kt demo` for three synthetic toasts, a mouse tooltip and an isolated tint, or `/kt preview` to choose one sample. Samples leave real loot state and settings intact. `/kt help` groups the commands, and `/kt status` reports your current scope and settings.
