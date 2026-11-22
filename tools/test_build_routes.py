"""Tests for tools/build-routes.py on a tiny catalog and route (no network)."""
import importlib.util
import os
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("build_routes", os.path.join(HERE, "build-routes.py"))
br = importlib.util.module_from_spec(spec)
spec.loader.exec_module(br)

CATALOG = '''ns.Data.Catalog_Era = {
  recipes = {
    [3275] = { p = "firstaid", learn = 1, make = 1251, n = 1, r = { 2589, 1 } },
    [3276] = { p = "firstaid", learn = 40, make = 2581, n = 1, r = { 2589, 2 }, y = 50, gy = 100 },
    [7928] = { p = "firstaid", learn = 150, make = 6450, n = 1, r = { 4306, 1 } },
    [18629] = { p = "firstaid", learn = 260, make = 14530, n = 1, r = { 14047, 2 } },
    [918629] = { p = "firstaid", learn = 1, make = 914530, n = 1, r = { 14047, 2 } },
    [7929] = { p = "firstaid", learn = 180, make = 6451, n = 1, r = { 4306, 2 } },
    [907929] = { p = "firstaid", learn = 1, make = 906451, n = 1, r = { 4306, 3 } },
  },
  itemNames = {
    [2589] = "Linen Cloth",
    [2592] = "Wool Cloth",
    [6450] = "Silk Bandage",
    [14530] = "Heavy Runecloth Bandage Item",
  },
  spellNames = {
    [3275] = "Linen Bandage",
    [3276] = "Heavy Linen Bandage",
    [7928] = "Silk Bandage",
    [18629] = "Heavy Runecloth Bandage",
    [918629] = "Heavy Runecloth Bandage",
    [7929] = "Heavy Silk Bandage",
    [907929] = "Heavy Silk Bandage",
  },
  endgame = {
  },
}
'''

ROUTE = """# guide: Example Guide
# url: https://example.test/first-aid
# checked: 2026-11-15
1-40 | Linen Bandage | 45
40-150 | Heavy Linen Bandage | 120
150-260 | 7928 | 130
260-300 | Heavy Runecloth Bandage | 50
"""


class ExpandTest(unittest.TestCase):
    """Inputs of intermediates the route needs more of than it crafts (design D2b)."""
    RECIPES = {
        1: {"p": "tailoring", "make": 100, "n": 1, "r": [(10, 4)]},      # Bolt <- 4 cloth
        2: {"p": "tailoring", "make": 200, "n": 1, "r": [(100, 3)]},     # Belt <- 3 bolts
        3: {"p": "mining", "make": 300, "n": 1, "r": [(30, 1)]},         # Bar <- Ore
        4: {"p": "blacksmithing", "make": 400, "n": 1, "r": [(300, 10)]},
        5: {"p": "mining", "make": 500, "n": 1, "r": [(300, 1), (50, 1)]},  # Steel <- Bar + Coal
    }
    NAMES = {"spell_by_id": {1: "Bolt", 2: "Belt", 3: "Smelt", 4: "Helm"}}

    def run_expand(self, segs, produced):
        return sorted(tuple(s) for s in br.expand([list(x) for x in segs], produced, self.RECIPES, self.NAMES, set()))

    def test_route_crafts_its_own_bolts(self):
        segs = [(10, 0, 250, 260, 960, 960, 100), (100, 0, 260, 280, 75, 75, 200)]
        out = self.run_expand(segs, {100: 240, 200: 25})
        self.assertEqual(out, sorted(segs), "enough bolts crafted: nothing added")

    def test_partial_shortfall(self):
        out = self.run_expand([(100, 0, 260, 280, 100, 100, 200)], {100: 60})
        self.assertIn((10, 0, 260, 280, 160, 160, 100), out, "40 missing bolts need 160 cloth")

    def test_two_levels_and_ranges(self):
        out = self.run_expand([(300, 0, 1, 50, 150, 160, 400)], {})
        self.assertIn((30, 0, 1, 50, 150, 160, 300), out, "ore for the bars, keeping the guide's range")

    def test_demand_added_by_another_expansion(self):
        out = self.run_expand([(300, 0, 1, 50, 230, 230, 400), (500, 0, 50, 100, 190, 190, 400)], {})
        ore = sum(s[5] for s in out if s[0] == 30)
        self.assertEqual(ore, 420, "ore for direct bars and for the bars inside steel")

    def test_low_and_high_shortfalls_separately(self):
        # Review finding 4: demand 100-200, the route makes 100: inputs 0-100, not 50-100.
        out = self.run_expand([(100, 0, 260, 280, 100, 200, 200)], {100: 100})
        cloth = [s for s in out if s[0] == 10]
        self.assertEqual((sum(s[4] for s in cloth), sum(s[5] for s in cloth)), (0, 400), "4 cloth per bolt: 0-100 bolts")

    def test_rounding_keeps_totals(self):
        # Review finding 5: two segments need one each, one is made: one short, not two.
        out = self.run_expand([(100, 0, 1, 10, 1, 1, 200), (100, 0, 10, 20, 1, 1, 200)], {100: 1})
        cloth = [s for s in out if s[0] == 10]
        self.assertEqual(sum(s[5] for s in cloth), 4, "one bolt short: 4 cloth in total")

    def test_cycle_makes_no_demand(self):
        # Review finding 6: A <- B and B <- A; one A needed adds one B and nothing more.
        recipes = {1: {"p": "x", "make": 1, "n": 1, "r": [(2, 1)]}, 2: {"p": "x", "make": 2, "n": 1, "r": [(1, 1)]}}
        names = {"spell_by_id": {1: "A", 2: "B"}}
        out = br.expand([[1, 0, 1, 10, 1, 1, 9]], {}, recipes, names, set())
        totals = {}
        for s in out:
            totals[s[0]] = totals.get(s[0], 0) + s[5]
        self.assertEqual(totals, {1: 1, 2: 1})

    def test_distribute(self):
        self.assertEqual(br.distribute(1, [1, 1]), [1, 0])
        self.assertEqual(sum(br.distribute(7, [3, 3, 1])), 7)
        self.assertEqual(br.distribute(0, [5]), [0])

    def test_countless_still_marks_inputs(self):
        out = self.run_expand([(300, 0, 1, 50, 0, 0, 400)], {})
        self.assertIn((30, 0, 1, 50, 0, 0, 300), out)


class BuildRoutesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        cat = os.path.join(self.tmp.name, "Catalog_Era.lua")
        with open(cat, "w") as f:
            f.write(CATALOG)
        self.recipes, self.names = br.read_catalog(cat)
        self.client = os.path.join(self.tmp.name, "era")
        os.makedirs(os.path.join(self.client, "example"))

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, text):
        with open(os.path.join(self.client, "example", "firstaid.txt"), "w") as f:
            f.write(text)

    def test_counts_are_crafts_times_reagents(self):
        self.write(ROUTE)
        guides, seg = br.build(self.client, self.recipes, self.names)
        self.assertEqual(guides, [{"name": "Example Guide", "url": "https://example.test/first-aid", "checked": "2026-11-15"}])
        self.assertEqual(seg["firstaid"][2589], [(0, 1, 40, 45, 45, 1251), (0, 40, 150, 240, 240, 2581)], "linen: 45x1 then 120x2")
        self.assertEqual(seg["firstaid"][4306], [(0, 150, 260, 130, 130, 6450)], "a spell ID works as the recipe")
        self.assertEqual(seg["firstaid"][14047], [(0, 260, 300, 100, 100, 14530)])

    def test_step_without_count_marks_only(self):
        self.write(ROUTE.replace("Heavy Runecloth Bandage | 50", "Heavy Runecloth Bandage |"))
        _, seg = br.build(self.client, self.recipes, self.names)
        self.assertEqual(seg["firstaid"][14047], [(0, 260, 300, 0, 0, 14530)], "no count: 0, 0")

    def test_block_totals(self):
        self.write(ROUTE + "= 81-150 | Wool Cloth | 100-120\n= 1-80 | Linen Cloth | 170\n")
        _, seg = br.build(self.client, self.recipes, self.names)
        self.assertEqual(seg["firstaid"][2592], [(0, 81, 150, 100, 120, 0)])
        self.assertEqual(seg["firstaid"][2589][-1], (0, 1, 80, 170, 170, 0), "a single total is low = high")
        self.write(ROUTE + "= 81-150 | Mystery Cloth | 5\n")
        with self.assertRaisesRegex(ValueError, "matches 0 items"):
            br.build(self.client, self.recipes, self.names)
        self.write(ROUTE + "= 81-150 | Wool Cloth | 120-100\n")
        with self.assertRaisesRegex(ValueError, "reversed"):
            br.build(self.client, self.recipes, self.names)

    def test_step_named_by_item_made(self):
        self.write(ROUTE.replace("Heavy Runecloth Bandage | 50", "Heavy Runecloth Bandage Item | 50"))
        _, seg = br.build(self.client, self.recipes, self.names)
        self.assertEqual(seg["firstaid"][14047], [(0, 260, 300, 100, 100, 14530)], "resolved by the item the recipe makes")

    def test_duplicates(self):
        self.write(ROUTE)
        _, seg = br.build(self.client, self.recipes, self.names)
        self.assertEqual(seg["firstaid"][14047], [(0, 260, 300, 100, 100, 14530)], "same reagents: the original recipe")
        self.write(ROUTE.replace("150-260 | 7928 | 130", "150-260 | Heavy Silk Bandage | 130"))
        with self.assertRaisesRegex(ValueError, "matches 2 firstaid recipes"):
            br.build(self.client, self.recipes, self.names)

    def test_render(self):
        self.write(ROUTE)
        text = br.render("era", *br.build(self.client, self.recipes, self.names))
        self.assertIn("ns.Data.Routes_Era = {", text)
        self.assertIn("[2589] = { 1, 1, 40, 45, 45, 1251, 1, 40, 150, 240, 240, 2581 },", text)

    def test_gap_and_end_are_errors(self):
        self.write(ROUTE.replace("40-150", "50-150"))
        with self.assertRaisesRegex(ValueError, "gap from 40 to 50"):
            br.build(self.client, self.recipes, self.names)
        self.write(ROUTE.replace("40-150", "41-150"))
        br.build(self.client, self.recipes, self.names)  # starting one point later is not a gap
        self.write(ROUTE.replace("260-300", "260-290"))
        with self.assertRaisesRegex(ValueError, "ends at 290"):
            br.build(self.client, self.recipes, self.names)

    def test_unknown_recipe_and_missing_header(self):
        self.write(ROUTE.replace("Linen Bandage | 45", "Wool Bandage | 45"))
        with self.assertRaisesRegex(ValueError, "matches 0 firstaid recipes"):
            br.build(self.client, self.recipes, self.names)
        self.write(ROUTE.replace("# checked: 2026-11-15\n", ""))
        with self.assertRaisesRegex(ValueError, "missing '# checked:'"):
            br.build(self.client, self.recipes, self.names)


if __name__ == "__main__":
    unittest.main()
