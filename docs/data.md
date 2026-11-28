# Data

Everything KeepThat marks comes from four generated files in `KeepThat/Data/`, one catalog and one routes file per client. Each TOC loads only its own client's pair (`_Vanilla.toc` the `_Era` files, `_Camelot.toc` the `_Forever` files), and `Core/Client.lua` sets `ns.client` from whichever catalog loaded. Never edit these files by hand: change the inputs below and run `make catalog`.

```
DB2 tables (wago.tools, pinned build) --+
tools/endgame/<client>/<profession>.txt +--> tools/build-catalog.py --> Data/Catalog_<Client>.lua
tools/no-expand.txt --------------------+                                     |
                                                                              v
tools/routes/<client>/<guide>/<profession>.txt ----> tools/build-routes.py --> Data/Routes_<Client>.lua
```

## Inputs

### Game data

`tools/build-catalog.py` downloads SkillLineAbility, SpellReagents, SpellEffect, SpellName and ItemSparse for the pinned build (`BUILDS` at the top of the script) into `tools/.cache/<build>/`. It keeps the recipes of the crafting professions (Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, First Aid and Mining smelting) with a learn skill from 1 to 300 and at least one reagent. Comprehension and the gathering professions are not covered.

### Endgame lists: `tools/endgame/<client>/<profession>.txt`

One material per line, `'#'` starts a comment:

```
<itemID> | <reason> | <source>
12360 | Best-in-slot crafted gear | https://www.wowhead.com/classic/item=12360 (reviewed 2026-11-15)  # Arcanite Bar
```

- The reason is shown in the Shift details ("Blacksmithing: Best-in-slot crafted gear").
- The source must be a citation; every source is credited in `THIRD_PARTY.md`.
- The build fails if a listed item is not a reagent of a recipe of that profession, so a typo or a wrong profession is caught.
- The WoW Forever lists are a copy of the Classic Era lists until Forever's own content and guides settle.

### Leveling routes: `tools/routes/<client>/<guide>/<profession>.txt`

Facts only, never a guide's text:

```
# guide: wow-professions.com
# url: https://wow-professions.com/classic/first-aid-leveling-guide-classic-wow
# checked: 2026-11-15
1-40 | Linen Bandage | 50              <from>-<to> | <recipe name or spell ID> | <crafts>
290-300 | Heavy Runecloth Bandage |     a step the guide gives no count for: marks only
= 1-125 | Linen Cloth | 160-180         a guide's material total for a block of skill
```

- **Recipes** resolve against that client's catalog by spell name. If no recipe has that name, they resolve by the name of the item the recipe makes ("Essence of Fire" for "Transmute: Air to Fire"). Use a spell ID when a name matches more than one recipe. Duplicate rows with identical reagents (a client's leftover copy) resolve to the original automatically.
- **Coverage:** a route must run from 1 to 300 with no gap. A step may start one point after the previous one ends (41-50 after 1-40).
- **Guides recorded:**
  - Classic Era: wow-professions.com and Wowhead.
  - WoW Forever: Metabot and RankedBoost. Metabot's route is computed by its planner and is re-planned often, so re-read it whenever the pinned catalog build moves. A RankedBoost page shows an "Updated" date; compare it with the `# checked:` line.

  Icy Veins and Mobalytics refuse automated reads.

### Not expanded: `tools/no-expand.txt`

Item IDs that are never expanded into their inputs (mostly gathered or dropped, though a recipe can make them). One ID per line. It is empty for now.

## Expansion: materials made from other materials

`tools/chain.py` holds the rule both generators share (design D2b). An item is expanded into its recipe's inputs when all of these hold:

- exactly one recipe makes it on that client (identical-reagent duplicates count as one);
- that recipe is not an element conversion (`Transmute: X to Y`);
- the item is not in `no-expand.txt`.

The walk stops after four levels.

- **Endgame:** the inputs become endgame materials of the same profession, with `via` set to the item they make (Thorium Ore via Thorium Bar via Arcanite Bar).
- **Leveling:** only the shortfall is added: what the route needs of an intermediate minus what its own steps craft. The low and high shortfalls are worked out separately, rounded to whole crafts once, and spread over the consuming steps' skill ranges so the totals stay exact. The expansion repeats until it is stable, and an input that is one of its own ancestors is skipped. So a route that crafts its own bolts is not counted twice, the Iron Bars inside Steel Bars still add Iron Ore, and a recipe cycle cannot make up demand.

## Recipe difficulty

Each recipe carries `y`, the rank where it turns yellow, and `gy`, the rank where it turns gray. They come from SkillLineAbility's `TrivialSkillLineRankLow` and `TrivialSkillLineRankHigh`. Both are left out when either is 0 or gray is below yellow. `Model/RecipeKnowledge.lua` works out the rest:

- Green starts at `floor((y + gy) / 2)`.
- Below yellow, a recipe is Orange only when the character has learned it.
- `learn` (MinSkillLineRank) is 1 for many trainer recipes on Classic, so it is not the required skill. The required skill is not in the data.

## Output formats

### `Data/Catalog_<Client>.lua` (`ns.Data.Catalog_Era` / `_Forever`)

```lua
{
  client = "era", build = "1.15.9.70576",
  recipes = { [spellID] = { p = "blacksmithing", learn = 300, make = itemID, n = 1, r = { itemID, qty, ... }, y = 275, gy = 290 } },
  itemNames = { [itemID] = "English name" },    -- fallback until the client has the item cached
  spellNames = { [spellID] = "English name" },
  endgame = { [itemID] = { profession = { reason, source, via } } },   -- via 0 for listed items
}
```

### `Data/Routes_<Client>.lua` (`ns.Data.Routes_Era` / `_Forever`)

```lua
{
  guides = { { name = "wow-professions.com", url = "...", checked = "2026-11-15" }, ... },
  materials = { profession = { [itemID] = { guide, from, to, low, high, via, ... } } },
}
```

- `guide` is a 1-based index into `guides`.
- `low` and `high` are the counts for the segment. `0, 0` means the guide gives no count.
- `via` is the item the material goes into. It is the step's product, or the intermediate for expanded inputs, and 0 for a guide's block total.

`Model/Leveling.lua` sums each guide's segments still ahead of the player's skill (part of a segment counts in proportion). It shows one number when the guides agree, and a range from the smallest to the largest otherwise. A guide whose steps for the material are all behind the player counts as 0, so `0-55` means one guide is done with it and another still needs 55. The "for <intermediate>" breakdown takes the largest guide's share, never the sum across guides.

## Checks

- `tools/test_build_catalog.py`, `tools/test_build_routes.py` (`make test-py`): the generators on small fixtures.
- `tests/test_data.lua`: both catalogs load. Every endgame entry has a known profession, a reason and a source, and is a reagent of some recipe.
- `tests/test_client.lua`: each TOC loads only its own client's data.
