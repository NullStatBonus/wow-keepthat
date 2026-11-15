"""Shared rule for walking down recipe chains (design D2b), used by build-catalog.py and build-routes.py.

An item is expanded into its inputs when exactly one recipe on the client makes it, that recipe is not
an element conversion ("Transmute: Air to Fire"), and the item is not listed in tools/no-expand.txt.
"""
import os
import re

MAX_DEPTH = 4
CONVERSION = re.compile(r"^Transmute: \w[\w' ]* to \w[\w' ]*$")


def read_no_expand(path):
    """Item IDs never expanded, one per line ('#' starts a comment)."""
    out = set()
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    out.add(int(line))
    return out


def makers(recipes):
    """itemID -> list of spell IDs whose recipe makes it."""
    out = {}
    for spell, rec in recipes.items():
        if rec.get("make"):
            out.setdefault(rec["make"], []).append(spell)
    return out


def recipe_for(item, made_by, recipes, spell_names, no_expand):
    """The one recipe to expand item through, or None."""
    if item in no_expand:
        return None
    spells = made_by.get(item, [])
    if len(spells) > 1 and len({tuple(recipes[s]["r"]) for s in spells}) == 1:
        spells = [min(spells)]  # a client's leftover copy with the same reagents
    if len(spells) != 1:
        return None
    if CONVERSION.match(spell_names.get(spells[0], "")):
        return None
    return spells[0]
