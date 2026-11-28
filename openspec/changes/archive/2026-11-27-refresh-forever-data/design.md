# Design

## Context

See proposal.md - Why. The Forever catalog is built by `tools/build-catalog.py` from DB2 tables pinned in `BUILDS`. Routes are built by `tools/build-routes.py` from fact-only files in `tools/routes/<client>/<guide>/<profession>.txt`; each step must resolve against that client's catalog by recipe name, and a route must cover 1 to 300. Forever has two guides: Metabot (a computed route) and RankedBoost (an editorial route). Measured 2026-11-27: RankedBoost matched our snapshot in every profession except Blacksmithing (3 of 21 steps changed); Metabot matched in few steps in any profession, and its total crafts rose 2% (Cooking) to 24% (Blacksmithing).

## Goals / Non-Goals

**Goals:**
- Forever catalog and routes agree with the current client build and the guides as they stand.
- Every route file shows a checked date, and `THIRD_PARTY.md` shows the build.
- `docs/contracts.md` describes DFL Profession Journal 3.16.97.

**Non-Goals:**
- Forever endgame lists. Raids open 2026-12-09 and loot is hidden until then; the Era drafts stay and keep their "unverified on Forever" source note.
- Any weighting of guides. The range display keeps taking the smallest and largest count across guides.
- Era data, DFL Profession Journal integration code, settings, or tooltips.

## Decisions

**Catalog first, then routes.** Routes resolve recipe names against the catalog, so bump `BUILDS["forever"]` and regenerate the catalog first. Diff the generated file against the old one (recipes added, removed, moved profession, changed reagents or thresholds) before touching routes. A step that no longer resolves fails `build-routes.py`, which is the check we want. Alternative: re-snapshot routes against the old build first. Rejected: the guides were written for the newer client.

**Pin to the newest build at the time of work.** Today that is 71139 (2026-11-25). Re-check `wago.tools/builds` when starting. Do not move the pin mid-change.

**Snapshot by reading the guide pages, committing facts only.** Extract step ranges, recipe names and craft counts into the existing `from-to | recipe | crafts` format, as before. Use a throwaway script in the session scratchpad for extraction and compare with the committed files; commit only the `.txt` outputs. No guide text is copied. Alternative: add a scraper to `tools/`. Rejected: the pages change layout, the work recurs only a few times a year, and a scraper adds maintenance and a terms-of-use question for no player benefit.

**Metabot stays a source, unweighted.** Its route is recomputed by its planner, so it will drift again. The count range already tells players that guides disagree. Open policy options (drop it, pin it per build, or weight it) are deferred. Record in `docs/data.md` that Metabot routes are recomputed and must be re-snapshotted whenever the catalog build moves.

**DFL Profession Journal: documentation only.** The 3.16.97 source (read in a scratch folder, nothing copied) keeps every entry point in the contract: `GuideData`, `Leveling.OrderedSteps(steps, faction)`, `API.Faction()`, `DFLPJ_OpenPage`, `DFLPJ_ToggleJournal`, `DFLPJ_ToggleTracker`, `UI:OpenRecipeInJournal`, and the "Your route" tooltip row. Its changelog since 3.16.76 lists no route-data change, but `DataCore.lua` grew about 0.2% and the pipeline id is unchanged, so route values are unverified between the two builds. It also ships a LibDataBroker launcher and a minimap crest, and its `GuideComparisonData.lua` names other Forever guides (wow-professions.com/forever, classicwowforever.com, zockify.com) with dates from 2025-02 to 2026-09.

## Risks / Trade-offs

- [Hard-coded Forever numbers in tests break] -> Update the expected values from the regenerated data; check each changed value is explained by a route or recipe change, not accepted blindly.
- [A guide step names a recipe the new build lacks or renames] -> The route build fails on an unresolved name; fix the name or use a spell ID, as the data docs describe.
- [Metabot drifts again soon] -> Accepted; the checked date makes staleness visible. Revisit the policy separately.
- [Counts rise for players with Forever] -> Intended. Say so in the changelog.
- [Guide pages block automated reads] -> Use a browser to read them; if a page cannot be read, keep the old snapshot for that file and say so in the commit and changelog.

## Migration Plan

Regenerate with `make catalog`, run `make test` and `make check`, then archive with a patch version bump in both TOC files. Rollback is reverting the commit; saved variables are untouched.
