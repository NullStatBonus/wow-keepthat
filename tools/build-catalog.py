#!/usr/bin/env python3
"""Builds KeepThat/Data/Catalog_<Client>.lua from one client's DB2 tables (design D2).

Usage (from the repository root):
    python3 tools/build-catalog.py --client era
    python3 tools/build-catalog.py --client forever

The DB2 tables are downloaded as CSV from wago.tools for the pinned build and cached in
tools/.cache/<build>/. The curated endgame lists in tools/endgame/<client>/<profession>.txt decide
which items are endgame materials; this script only adds the recipe facts from the game data.

Endgame list format, one item per line ('#' starts a comment):
    <itemID> | <reason> | <source>
"""
import argparse
import csv
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chain  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Pinned builds; bump these to regenerate from a newer client.
BUILDS = {"era": "1.15.9.70576", "forever": "1.60.1.70938"}
CLIENT_NAMES = {"era": "Era", "forever": "Forever"}

# Crafting skill lines (the IDs are the same on both clients). Mining is here for smelting.
PROFESSIONS = {
    171: "alchemy", 164: "blacksmithing", 333: "enchanting", 202: "engineering",
    165: "leatherworking", 197: "tailoring", 185: "cooking", 129: "firstaid", 186: "mining",
}
MAX_SKILL = 300
CREATE_ITEM = 24
TABLES = ("SkillLineAbility", "SpellReagents", "SpellEffect", "SpellName", "ItemSparse")


def fetch(table, build, cache):
    path = os.path.join(cache, build, table + ".csv")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build)
        with urllib.request.urlopen(url, timeout=300) as resp, open(path + ".part", "wb") as out:
            out.write(resp.read())
        os.replace(path + ".part", path)
    return path


def rows(path):
    with open(path, encoding="utf-8", newline="") as f:
        yield from csv.DictReader(f)


def num(value, default=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def create_count(row):
    """Items one cast makes. Forever stores it in EffectBasePointsF; Era in BasePoints + DieSides."""
    if "EffectBasePoints" in row:
        return max(1, num(row["EffectBasePoints"]) + num(row.get("EffectDieSides")))
    return max(1, num(row.get("EffectBasePointsF")))


def build_recipes(tables):
    """tables: name -> iterable of CSV rows. Returns (recipes, item_names, spell_names)."""
    abilities = {}
    for r in tables["SkillLineAbility"]:
        prof = PROFESSIONS.get(num(r["SkillLine"]))
        rank = num(r["MinSkillLineRank"])
        if prof and 0 < rank <= MAX_SKILL:
            abilities[num(r["Spell"])] = (prof, rank)

    reagents = {}
    for r in tables["SpellReagents"]:
        spell = num(r["SpellID"])
        if spell in abilities:
            pairs = []
            for i in range(8):
                item, qty = num(r.get("Reagent_%d" % i)), num(r.get("ReagentCount_%d" % i))
                if item > 0 and qty > 0:
                    pairs.append((item, qty))
            if pairs:
                reagents[spell] = pairs

    makes = {}
    for r in tables["SpellEffect"]:
        spell = num(r["SpellID"])
        if spell in reagents and num(r["Effect"]) == CREATE_ITEM and num(r["EffectItemType"]) > 0 and spell not in makes:
            makes[spell] = (num(r["EffectItemType"]), create_count(r))

    recipes = {}
    for spell, pairs in reagents.items():
        prof, rank = abilities[spell]
        make, count = makes.get(spell, (0, 0))
        recipes[spell] = {"p": prof, "learn": rank, "make": make, "n": count, "r": pairs}

    wanted = set()
    for rec in recipes.values():
        wanted.update(item for item, _ in rec["r"])
        if rec["make"]:
            wanted.add(rec["make"])
    item_names = {}
    for r in tables["ItemSparse"]:
        item = num(r["ID"])
        if item in wanted and r.get("Display_lang"):
            item_names[item] = r["Display_lang"]
    spell_names = {}
    for r in tables["SpellName"]:
        spell = num(r["ID"])
        if spell in recipes and r.get("Name_lang"):
            spell_names[spell] = r["Name_lang"]
    return recipes, item_names, spell_names


def read_endgame(folder):
    """Returns item -> {profession: (reason, source)} from tools/endgame/<client>/<profession>.txt."""
    out = {}
    if not os.path.isdir(folder):
        return out
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".txt"):
            continue
        prof = name[:-4]
        if prof not in PROFESSIONS.values():
            raise ValueError("%s: unknown profession '%s'" % (folder, prof))
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                line = line.split("#", 1)[0].strip()
                if not line:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) != 3 or not parts[0].isdigit() or not parts[1] or not parts[2]:
                    raise ValueError("%s:%d: expected '<itemID> | <reason> | <source>'" % (name, lineno))
                out.setdefault(int(parts[0]), {})[prof] = (parts[1], parts[2])
    return out


def check_endgame(endgame, recipes):
    """Every endgame item must be a reagent of at least one recipe of the profession that lists it."""
    used = {}
    for rec in recipes.values():
        for item, _ in rec["r"]:
            used.setdefault(item, set()).add(rec["p"])
    problems = []
    for item in sorted(endgame):
        for prof in sorted(endgame[item]):
            if prof not in used.get(item, ()):
                problems.append("%d is listed for %s but no %s recipe uses it" % (item, prof, prof))
    return problems


def expand_endgame(endgame, recipes, item_names, spell_names, no_expand):
    """Adds the inputs of endgame materials that a recipe makes (design D2b). Entries become
    (reason, source, via); via is the item the input is used to make, 0 for listed items."""
    out = {item: {p: (r, s, 0) for p, (r, s) in profs.items()} for item, profs in endgame.items()}
    made_by = chain.makers(recipes)
    queue = [(item, prof, src, 0) for item, profs in endgame.items() for prof, (_, src) in profs.items()]
    while queue:
        item, prof, src, depth = queue.pop(0)
        if depth >= chain.MAX_DEPTH:
            continue
        spell = chain.recipe_for(item, made_by, recipes, spell_names, no_expand)
        if spell is None:
            continue
        for reagent, _ in recipes[spell]["r"]:
            if prof in out.get(reagent, {}):
                continue
            reason = "Used to make %s" % item_names.get(item, str(item))
            out.setdefault(reagent, {})[prof] = (reason, src, item)
            queue.append((reagent, prof, src, depth + 1))
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def render(client, build, recipes, item_names, spell_names, endgame):
    var = "Catalog_" + CLIENT_NAMES[client]
    out = [
        "-- Generated by tools/build-catalog.py from wago.tools DB2 build %s. Do not edit by hand." % build,
        "local _, ns = ...",
        "ns.Data = ns.Data or {}",
        "ns.Data.%s = {" % var,
        "  client = %s, build = %s," % (lua_str(client), lua_str(build)),
        "  -- spellID = { p = profession, learn = skill, make = itemID, n = count made, r = { itemID, qty, ... } }",
        "  recipes = {",
    ]
    for spell in sorted(recipes):
        rec = recipes[spell]
        flat = ", ".join("%d, %d" % pair for pair in rec["r"])
        out.append("    [%d] = { p = %s, learn = %d, make = %d, n = %d, r = { %s } }," % (
            spell, lua_str(rec["p"]), rec["learn"], rec["make"], rec["n"], flat))
    out.append("  },")
    out.append("  -- English names, a fallback until the client has the item or spell cached.")
    out.append("  itemNames = {")
    for item in sorted(item_names):
        out.append("    [%d] = %s," % (item, lua_str(item_names[item])))
    out.append("  },")
    out.append("  spellNames = {")
    for spell in sorted(spell_names):
        out.append("    [%d] = %s," % (spell, lua_str(spell_names[spell])))
    out.append("  },")
    out.append("  -- itemID = { profession = { reason, source, via } }, from tools/endgame/%s/; via is the item" % client)
    out.append("  -- an added input is used to make (0 for listed items).")
    out.append("  endgame = {")
    for item in sorted(endgame):
        profs = ", ".join("%s = { %s, %s, %d }" % (p, lua_str(r), lua_str(s), via) for p, (r, s, via) in sorted(endgame[item].items()))
        out.append("    [%d] = { %s }," % (item, profs))
    out.append("  },")
    out.append("}")
    return "\n".join(out) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--client", choices=sorted(BUILDS), required=True)
    ap.add_argument("--build", help="override the pinned build")
    ap.add_argument("--cache", default=os.path.join(ROOT, "tools", ".cache"))
    ap.add_argument("--out", help="output file (default KeepThat/Data/Catalog_<Client>.lua)")
    args = ap.parse_args(argv)
    build = args.build or BUILDS[args.client]
    tables = {t: rows(fetch(t, build, args.cache)) for t in TABLES}
    recipes, item_names, spell_names = build_recipes(tables)
    endgame = read_endgame(os.path.join(ROOT, "tools", "endgame", args.client))
    problems = check_endgame(endgame, recipes)
    if problems:
        sys.exit("%s endgame lists:\n  %s" % (args.client, "\n  ".join(problems)))
    no_expand = chain.read_no_expand(os.path.join(ROOT, "tools", "no-expand.txt"))
    listed = len(endgame)
    endgame = expand_endgame(endgame, recipes, item_names, spell_names, no_expand)
    out = args.out or os.path.join(ROOT, "KeepThat", "Data", "Catalog_%s.lua" % CLIENT_NAMES[args.client])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(args.client, build, recipes, item_names, spell_names, endgame))
    print("%s: %d recipes, %d items, %d endgame materials (%d listed) -> %s" % (
        args.client, len(recipes), len(item_names), len(endgame), listed, os.path.relpath(out, ROOT)))


if __name__ == "__main__":
    main()
