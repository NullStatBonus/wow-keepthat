"""Tests for tools/build-catalog.py on small in-memory tables (no network)."""
import importlib.util
import os
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("build_catalog", os.path.join(HERE, "build-catalog.py"))
bc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bc)


def sla(spell, line, rank):
    return {"SkillLine": str(line), "Spell": str(spell), "MinSkillLineRank": str(rank)}


def reag(spell, *pairs):
    row = {"SpellID": str(spell)}
    for i in range(8):
        item, qty = pairs[i] if i < len(pairs) else (0, 0)
        row["Reagent_%d" % i], row["ReagentCount_%d" % i] = str(item), str(qty)
    return row


TABLES = {
    "SkillLineAbility": [
        sla(17187, 171, 275),   # Transmute: Arcanite (alchemy)
        sla(3931, 202, 125),    # Coarse Dynamite (engineering)
        sla(999, 171, 325),     # above 300: dropped
        sla(55, 6, 1),          # not a profession: dropped
        sla(777, 197, 1),       # no reagents: dropped
    ],
    "SpellReagents": [reag(17187, (12363, 1), (12359, 1)), reag(3931, (4364, 3), (2589, 1)), reag(999, (1, 1))],
    "SpellEffect": [
        {"SpellID": "17187", "Effect": "24", "EffectItemType": "12360", "EffectBasePoints": "0", "EffectDieSides": "0"},
        {"SpellID": "3931", "Effect": "24", "EffectItemType": "4365", "EffectBasePoints": "0", "EffectDieSides": "3"},
    ],
    "SpellName": [{"ID": "17187", "Name_lang": "Transmute: Arcanite"}, {"ID": "3931", "Name_lang": "Coarse Dynamite"}],
    "ItemSparse": [
        {"ID": "12360", "Display_lang": "Arcanite Bar"}, {"ID": "12363", "Display_lang": "Arcane Crystal"},
        {"ID": "12359", "Display_lang": "Thorium Bar"}, {"ID": "4365", "Display_lang": "Coarse Dynamite"},
        {"ID": "4364", "Display_lang": "Coarse Blasting Powder"}, {"ID": "2589", "Display_lang": "Linen Cloth"},
        {"ID": "1", "Display_lang": "Unused"},
    ],
}


class BuildCatalogTest(unittest.TestCase):
    def test_recipes_filtered_and_shaped(self):
        recipes, items, spells = bc.build_recipes(TABLES)
        self.assertEqual(sorted(recipes), [3931, 17187])
        self.assertEqual(recipes[17187], {"p": "alchemy", "learn": 275, "make": 12360, "n": 1, "r": [(12363, 1), (12359, 1)]})
        self.assertEqual(recipes[3931]["n"], 3, "Era count is BasePoints + DieSides")
        self.assertNotIn(1, items, "items only from kept recipes")
        self.assertEqual(items[12363], "Arcane Crystal")
        self.assertEqual(spells[3931], "Coarse Dynamite")

    def test_forever_count_from_float_points(self):
        self.assertEqual(bc.create_count({"EffectBasePointsF": "2.0"}), 2)
        self.assertEqual(bc.create_count({"EffectBasePointsF": "0"}), 1)

    def test_endgame_lists(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "alchemy.txt"), "w") as f:
                f.write("# comment\n12363 | Arcanite transmute for endgame gear | https://example.test/guide\n\n")
            self.assertEqual(bc.read_endgame(d), {12363: {"alchemy": ("Arcanite transmute for endgame gear", "https://example.test/guide")}})
            with open(os.path.join(d, "alchemy.txt"), "w") as f:
                f.write("12363 | missing source\n")
            with self.assertRaises(ValueError):
                bc.read_endgame(d)
            os.remove(os.path.join(d, "alchemy.txt"))
            with open(os.path.join(d, "juggling.txt"), "w") as f:
                f.write("1 | a | b\n")
            with self.assertRaises(ValueError):
                bc.read_endgame(d)

    def test_endgame_item_must_be_used_by_that_profession(self):
        recipes, _, _ = bc.build_recipes(TABLES)
        self.assertEqual(bc.check_endgame({12363: {"alchemy": ("r", "s")}}, recipes), [])
        self.assertEqual(bc.check_endgame({12363: {"engineering": ("r", "s")}}, recipes),
                         ["12363 is listed for engineering but no engineering recipe uses it"])
        self.assertEqual(bc.check_endgame({1: {"alchemy": ("r", "s")}}, recipes),
                         ["1 is listed for alchemy but no alchemy recipe uses it"])

    def test_expand_endgame(self):
        recipes = {
            17187: {"p": "alchemy", "make": 12360, "n": 1, "r": [(12363, 1), (12359, 1)]},   # Arcanite
            16153: {"p": "mining", "make": 12359, "n": 1, "r": [(10620, 1)]},               # Thorium Bar <- Ore
            17559: {"p": "alchemy", "make": 7078, "n": 1, "r": [(7082, 1)]},                # Air to Fire
            1: {"p": "alchemy", "make": 9999, "n": 1, "r": [(1, 1)]},
            2: {"p": "alchemy", "make": 9999, "n": 1, "r": [(2, 1)]},                       # two makers
        }
        names = {12360: "Arcanite Bar", 12359: "Thorium Bar"}
        spells = {17187: "Transmute: Arcanite", 16153: "Smelt Thorium", 17559: "Transmute: Air to Fire"}
        listed = {12360: {"blacksmithing": ("Gear", "src")}, 7078: {"blacksmithing": ("Gear", "src")},
                  9999: {"alchemy": ("x", "src")}}
        out = bc.expand_endgame(listed, recipes, names, spells, set())
        self.assertEqual(out[12360]["blacksmithing"], ("Gear", "src", 0))
        self.assertEqual(out[12363]["blacksmithing"], ("Used to make Arcanite Bar", "src", 12360))
        self.assertEqual(out[10620]["blacksmithing"], ("Used to make Thorium Bar", "src", 12359), "two levels down")
        self.assertNotIn(7082, out, "an element conversion is not expanded")
        self.assertNotIn(1, out, "an item two recipes make is not expanded")
        self.assertNotIn(10620, bc.expand_endgame(listed, recipes, names, spells, {12359}), "no-expand list")

    def test_render_is_lua(self):
        recipes, items, spells = bc.build_recipes(TABLES)
        text = bc.render("era", "1.15.9.1", recipes, items, spells, {12363: {"alchemy": ('Says "keep"', "src", 0)}})
        self.assertIn("ns.Data.Catalog_Era = {", text)
        self.assertIn('[17187] = { p = "alchemy", learn = 275, make = 12360, n = 1, r = { 12363, 1, 12359, 1 } },', text)
        self.assertIn('[12363] = { alchemy = { "Says \\"keep\\"", "src", 0 } },', text)


if __name__ == "__main__":
    unittest.main()
