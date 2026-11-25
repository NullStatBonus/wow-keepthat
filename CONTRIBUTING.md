# Contributing

Thanks for helping. KeepThat is a WoW Classic addon (Lua) that adds a short tooltip line to the materials worth keeping for endgame crafting or profession leveling. It supports WoW Forever and Classic Era.

## Ways to help

- **Report a bug.** Type `/kt debug on`, do the thing that went wrong, then type `/kt log`, copy the report (Ctrl+A, Ctrl+C) and attach it with a short description and your client (Classic Era or Forever).
- **Correct the data.** A material that is marked wrong, or a count that looks wrong, is a real bug. Open an issue or a pull request with a source: an expert guide or the game's own recipe data.
- **Fix or build something.** For anything bigger than a small fix, open an issue first so we agree on the approach before you write it.

## Setup

1. Clone the repository and link or copy `KeepThat/` into your AddOns folder (`_classic_era_` or `_classic_beta_` for Forever).
2. Install [LuaJIT](https://luajit.org) and Python 3, then run from the repository root:

   ```
   make test     # LuaJIT tests plus Python tests
   make check    # TOC, embeds and version checks; CI and the release workflow run the same
   make plan     # validate and compile the in-game test plan (needs ../wow-checkthat, see docs/test-plan.md)
   ```

3. In game, `/reload` after a change, and `/console scriptErrors 1` so errors show as popups.

## How changes are made

Behavior is specified in `openspec/specs/`. A change to behavior goes through an OpenSpec change under `openspec/changes/` (proposal, design, spec deltas, tasks), is implemented against its tasks, and is archived when done. Archiving applies the deltas to the main specs and bumps the version. Bug fixes that restore specified behavior can skip the proposal; add a test that fails without the fix.

## Code

- **Match the surrounding code**: naming, comment density and idiom. Keep changes small and focused.
- **Keep the game out of the logic.** `KeepThat/Model/` and `KeepThat/Data/` are plain Lua with no client calls, so they can be tested. All client API reads go through `KeepThat/Core/Adapter*.lua`, wrapped in `pcall`, so a missing or changed function degrades to "no data" instead of an error.
- **Integrations are optional.** Each lives in its own file under `KeepThat/Integrations/` and turns itself off on any failure.
- **Write tests** for every behavior change in `tests/` (one `test_<module>.lua` per module).
- **New files** go in both TOC files (`KeepThat_Vanilla.toc` and `KeepThat_Camelot.toc`) in the same order. `make check` fails if they differ.
- **Plain language.** Player-facing text has no internal terms.

## Data

- Translations: see `docs/localization.md`. Player-facing text is written `L["English sentence"]`.
- Files in `KeepThat/Data/` are **generated** by the scripts in `tools/`. Change the inputs or the generator and regenerate instead of editing them. Credit every source in `THIRD_PARTY.md`.
- Treat downloaded data as untrusted: keep it out of the repository, and run Python that reads it with `python3 -I`.

## Versions and releases

- Bump `## Version:` in **both** TOC files to the same value when a change's specs are applied. Before 1.0.0 a new capability or user-visible feature raises the minor number and a fix to existing behavior raises the patch number.
- Add a `## X.Y.Z` section to `CHANGELOG.md`.
- Releases are tagged `vX.Y.Z` on the commit that carries the bump; see `docs/publishing.md`. Maintainers publish.

## Commits and pull requests

- One logical change per commit. Subject line in the imperative, under about 70 characters; name the new version in a release commit.
- In the pull request, say what changed, why, and how you tested it. Include screenshots for anything on a settings page.
- Before you open it: the tests and checks pass, and you have not committed secrets, captures (`debug.txt`) or screenshots.
- Be kind in reviews. Disagree about the change, not the person.

## License

By contributing you agree that your contribution is licensed under the project's license (see `LICENSE`).
