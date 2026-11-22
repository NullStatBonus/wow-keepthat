#!/usr/bin/env python3
"""Builds KeepThat/Data/Routes_<Client>.lua from the guide routes in tools/routes/<client>/ (design D3).

Usage (from the repository root, after tools/build-catalog.py for the same client):
    python3 tools/build-routes.py --client era

Route files: tools/routes/<client>/<guide>/<profession>.txt. Facts only, never the guide's text:
    # guide: wow-professions.com
    # url: https://wow-professions.com/classic/first-aid-leveling-guide
    # checked: 2026-11-15
    1-40 | Linen Bandage | 45
    <from>-<to> | <recipe name or spell ID> | <crafts>
    <from>-<to> | <recipe name or spell ID> |            (the guide gives no count for this step)

    = <from>-<to> | <material name> | <low>[-<high>]   (a guide's material total for a block of skill)

A step without a count still marks its materials but adds nothing to the count (counts 0 = unknown).
A '=' line adds that material with the guide's own low-high total for the block.
Each step's materials are crafts x the recipe's reagent quantities from the generated catalog, so
counts always match the client's game data. When a route needs an intermediate (Bolt of Runecloth)
that its own steps do not craft enough of, the shortfall's inputs are added too (design D2b).
The output lists, for each profession and material, the segments { guide, from, to, low, high, via }
that Model/Leveling.lua adds up; via is the item the material goes into (0 for a guide's block total).
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chain  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT_NAMES = {"era": "Era", "forever": "Forever"}
STEP = re.compile(r"^(\d+)\s*-\s*(\d+)\s*\|\s*(.+?)\s*\|\s*(\d*)\s*$")
TOTAL = re.compile(r"^=\s*(\d+)\s*-\s*(\d+)\s*\|\s*(.+?)\s*\|\s*(\d+)(?:\s*-\s*(\d+))?\s*$")


def read_catalog(path):
    """Recipes and spell names from a generated Catalog_<Client>.lua (the only Lua we read here)."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    recipes = {}
    for m in re.finditer(r'\[(\d+)\] = \{ p = "(\w+)", learn = (\d+), make = (\d+), n = (\d+), r = \{ ([\d, ]+) \}(?:, y = \d+, gy = \d+)? \}', text):
        nums = [int(x) for x in m.group(6).split(",")]
        recipes[int(m.group(1))] = {"p": m.group(2), "make": int(m.group(4)), "n": int(m.group(5)),
                                    "r": list(zip(nums[0::2], nums[1::2]))}
    items = {}
    item_section = text[text.index("itemNames = {"):text.index("spellNames = {")]
    for m in re.finditer(r'\[(\d+)\] = "((?:[^"\\]|\\.)*)"', item_section):
        items.setdefault(m.group(2), []).append(int(m.group(1)))
    names, by_id = {}, {}
    spell_section = text[text.index("spellNames = {"):text.index("endgame = {")]
    for m in re.finditer(r'\[(\d+)\] = "((?:[^"\\]|\\.)*)"', spell_section):
        names.setdefault(m.group(2), []).append(int(m.group(1)))
        by_id[int(m.group(1))] = m.group(2)
    return recipes, {"spells": names, "items": items, "spell_by_id": by_id}


def parse_route(path):
    meta, steps, totals = {}, [], []
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    for lineno, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            m = re.match(r"#\s*(guide|url|checked):\s*(.+)$", line)
            if m:
                meta[m.group(1)] = m.group(2).strip()
            continue
        t = TOTAL.match(line)
        if t:
            low = int(t.group(4))
            high = int(t.group(5)) if t.group(5) else low
            if high < low:
                raise ValueError("%s:%d: range %d-%d is reversed" % (path, lineno, low, high))
            totals.append((int(t.group(1)), int(t.group(2)), t.group(3), low, high, lineno))
            continue
        m = STEP.match(line)
        if not m:
            raise ValueError("%s:%d: expected '<from>-<to> | <recipe> | <crafts>'" % (path, lineno))
        crafts = int(m.group(4)) if m.group(4) else None
        steps.append((int(m.group(1)), int(m.group(2)), m.group(3), crafts, lineno))
    for key in ("guide", "url", "checked"):
        if key not in meta:
            raise ValueError("%s: missing '# %s:' line" % (path, key))
    return meta, steps, totals


def resolve(recipe, profession, recipes, names, where):
    if recipe.isdigit():
        spell = int(recipe)
        if spell not in recipes:
            raise ValueError("%s: spell %d is not a recipe on this client" % (where, spell))
        return spell
    found = [s for s in names["spells"].get(recipe, []) if recipes.get(s, {}).get("p") == profession]
    if not found:
        # Some guides name a step by the item it makes ("Essence of Fire" for "Transmute: Air to Fire").
        made = set(names["items"].get(recipe, []))
        found = [s for s, rec in recipes.items() if rec["p"] == profession and rec.get("make") in made]
    if len(found) > 1 and len({tuple(recipes[s]["r"]) for s in found}) == 1:
        # Duplicate rows with the same reagents (a client's leftover copy) give the same materials.
        found = [min(found)]
    if len(found) != 1:
        raise ValueError("%s: recipe '%s' matches %d %s recipes (by name or by item made); use its spell ID" % (where, recipe, len(found), profession))
    return found[0]


def check_coverage(steps, where):
    """Steps must start at 1, end at 300, and leave no gap. Overlaps are allowed, and a step may
    start one point after the previous one ends (41-50 after 1-40), as some guides write ranges."""
    reach = 1
    for frm, to, _, _, lineno in sorted(steps):
        if to <= frm:
            raise ValueError("%s:%d: range %d-%d is empty" % (where, lineno, frm, to))
        if frm > reach + 1:
            raise ValueError("%s:%d: gap from %d to %d" % (where, lineno, reach, frm))
        reach = max(reach, to)
    if reach < 300:
        raise ValueError("%s: route ends at %d, not 300" % (where, reach))


def distribute(total, weights):
    """Split an integer total over weights so the parts add up to exactly total (largest remainder)."""
    if total <= 0 or not weights:
        return [0] * len(weights)
    weight_sum = sum(weights)
    if weight_sum <= 0:
        weights, weight_sum = [1] * len(weights), len(weights)
    exact = [total * w / weight_sum for w in weights]
    parts = [math.floor(x) for x in exact]
    order = sorted(range(len(weights)), key=lambda i: (parts[i] - exact[i], i))
    for i in order[:total - sum(parts)]:
        parts[i] += 1
    return parts


def expand(segs, produced, recipes, names, no_expand):
    """Adds the inputs of intermediates the route needs more of than it crafts (design D2b).
    segs: list of [item, gi, from, to, low, high, via]; produced: item -> count the steps craft.

    For each intermediate the low and high shortfalls are worked out separately (need - produced),
    turned into whole crafts once, and spread over the consuming segments so the totals stay exact.
    Each derived segment remembers the items above it, and an input that is one of its own ancestors
    is not added (a recipe cycle cannot make up demand). Repeats until stable, so demand added by one
    expansion (Iron Bar for Steel Bar) is expanded too."""
    made_by = chain.makers(recipes)
    base = [list(s) + [frozenset()] for s in segs]
    derived = []
    for _ in range(chain.MAX_DEPTH):
        every = base + derived
        new = []
        for item in sorted({s[0] for s in every}):
            spell = chain.recipe_for(item, made_by, recipes, names["spell_by_id"], no_expand)
            if spell is None:
                continue
            mine = [s for s in every if s[0] == item and item not in s[7]]
            if not mine:
                continue
            need_low, need_high = sum(s[4] for s in mine), sum(s[5] for s in mine)
            have = produced.get(item, 0)
            per = recipes[spell]["n"] or 1
            if need_high == 0:
                # Count-less steps: mark the inputs, with no count.
                crafts_low, crafts_high = [0] * len(mine), [0] * len(mine)
            else:
                if have >= need_high:
                    continue
                short_low, short_high = max(0, need_low - have), need_high - have
                crafts_low = distribute(math.ceil(short_low / per), [s[4] for s in mine])
                crafts_high = distribute(math.ceil(short_high / per), [s[5] for s in mine])
            for reagent, qty in recipes[spell]["r"]:
                for s, cl, ch in zip(mine, crafts_low, crafts_high):
                    path = s[7] | {item}
                    if reagent in path:
                        continue
                    if need_high and cl == 0 and ch == 0:
                        continue
                    new.append([reagent, s[1], s[2], s[3], cl * qty, ch * qty, item, path])
        if new == derived:
            break
        derived = new
    return [s[:7] for s in base + derived]


def build(client_dir, recipes, names, no_expand=frozenset()):
    """Returns (guides, segments): guides is a list of {name, url, checked}; segments is
    profession -> itemID -> list of (guide index, from, to, low, high, via)."""
    guides, index, segments = [], {}, {}
    for guide_dir in sorted(os.listdir(client_dir)) if os.path.isdir(client_dir) else []:
        folder = os.path.join(client_dir, guide_dir)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".txt"):
                continue
            profession = name[:-4]
            path = os.path.join(folder, name)
            meta, steps, totals = parse_route(path)
            check_coverage(steps, path)
            if meta["guide"] not in index:
                index[meta["guide"]] = len(guides)
                guides.append({"name": meta["guide"], "url": meta["url"], "checked": meta["checked"]})
            gi = index[meta["guide"]]
            segs, produced = [], {}
            for frm, to, recipe, crafts, lineno in steps:
                spell = resolve(recipe, profession, recipes, names, "%s:%d" % (path, lineno))
                rec = recipes[spell]
                if crafts is not None and rec["make"]:
                    produced[rec["make"]] = produced.get(rec["make"], 0) + crafts * (rec["n"] or 1)
                for item, qty in rec["r"]:
                    total = crafts * qty if crafts is not None else 0
                    segs.append([item, gi, frm, to, total, total, rec["make"]])
            for frm, to, material, low, high, lineno in totals:
                ids = names["items"].get(material, [])
                if len(ids) != 1:
                    raise ValueError("%s:%d: material '%s' matches %d items; check the name" % (path, lineno, material, len(ids)))
                segs.append([ids[0], gi, frm, to, low, high, 0])
            for item, *seg in expand(segs, produced, recipes, names, no_expand):
                segments.setdefault(profession, {}).setdefault(item, []).append(tuple(seg))
    return guides, segments


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(client, guides, segments):
    out = [
        "-- Generated by tools/build-routes.py from tools/routes/%s/. Do not edit by hand." % client,
        "local _, ns = ...",
        "ns.Data = ns.Data or {}",
        "ns.Data.Routes_%s = {" % CLIENT_NAMES[client],
        "  guides = {",
    ]
    for g in guides:
        out.append("    { name = %s, url = %s, checked = %s }," % (lua_str(g["name"]), lua_str(g["url"]), lua_str(g["checked"])))
    out.append("  },")
    out.append("  -- profession = { itemID = { guide, from, to, low, high, via, ... } }; 0, 0 means the guide gives")
    out.append("  -- no count; via is the item the material goes into (0 for a guide's block total)")
    out.append("  materials = {")
    for prof in sorted(segments):
        out.append("    %s = {" % prof)
        for item in sorted(segments[prof]):
            flat = ", ".join("%d, %d, %d, %d, %d, %d" % (g + 1, f, t, lo, hi, via) for g, f, t, lo, hi, via in segments[prof][item])
            out.append("      [%d] = { %s }," % (item, flat))
        out.append("    },")
    out.append("  },")
    out.append("}")
    return "\n".join(out) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--client", choices=sorted(CLIENT_NAMES), required=True)
    args = ap.parse_args(argv)
    name = CLIENT_NAMES[args.client]
    recipes, names = read_catalog(os.path.join(ROOT, "KeepThat", "Data", "Catalog_%s.lua" % name))
    try:
        no_expand = chain.read_no_expand(os.path.join(ROOT, "tools", "no-expand.txt"))
        guides, segments = build(os.path.join(ROOT, "tools", "routes", args.client), recipes, names, no_expand)
    except ValueError as err:
        sys.exit(str(err))
    out = os.path.join(ROOT, "KeepThat", "Data", "Routes_%s.lua" % name)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(args.client, guides, segments))
    print("%s: %d guides, %d professions -> %s" % (args.client, len(guides), len(segments), os.path.relpath(out, ROOT)))


if __name__ == "__main__":
    main()
