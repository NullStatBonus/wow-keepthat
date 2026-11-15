# Publishing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) from `.github/workflows/release.yml` and uploaded to CurseForge and Wago, plus a GitHub release.

## One-time setup

1. Create the addon project on each site and note its ID.
2. Add the IDs to both TOC files, `KeepThat/KeepThat_Vanilla.toc` and `KeepThat/KeepThat_Camelot.toc`:

   ```
   ## X-Curse-Project-ID: <CurseForge project ID>
   ## X-Wago-ID: <Wago project ID>
   ```

   The packager skips any site whose ID is missing.
3. Add these repository secrets (Settings > Secrets and variables > Actions): `CF_API_TOKEN`, `WAGO_API_TOKEN`. `GITHUB_TOKEN` is provided by GitHub and is passed to the packager as `GITHUB_OAUTH`.
4. Pick MIT as the license on each site. The repository's `LICENSE` ships inside the package; the Ace3 libraries keep their own in `KeepThat/Libs/LICENSE-Ace3.txt`.

## Releasing

1. Archive the change and bump `## Version:` in both TOC files (see `CLAUDE.md`), and add a `## X.Y.Z` section to `CHANGELOG.md`.
2. Commit, then tag the commit `vX.Y.Z` (the version without the `v` must equal the TOC version) and push the tag.
3. The workflow runs `make test` and `make check`, checks the tag against both TOC versions with `sh tools/check-version.sh "$GITHUB_REF_NAME"`, then packages and uploads to CurseForge and Wago, then creates the GitHub release with the zip attached.

## How the package is laid out

- The addon lives in `KeepThat/` inside the repository, so `.pkgmeta` moves it to the top of the zip and ignores everything else (tests, tools, docs, openspec, captures and screenshots).
- The Ace3 libraries are committed under `KeepThat/Libs`, so no externals are fetched.
- The packager treats `KeepThat_Camelot.toc` as the WoW Forever TOC (its name for the Forever client) and `KeepThat_Vanilla.toc` as Classic Era. A TOC named `_Forever` would not be recognized, so Forever would not be offered as a game version.
- Each TOC lists only its own client's data: `KeepThat_Vanilla.toc` loads `Data/*_Era.lua` and `KeepThat_Camelot.toc` loads `Data/*_Forever.lua`. Everything else is listed in both, in the same order (`tools/check-tocs-match.sh`).
- `CHANGELOG.md` is used as the changelog on every site (`manual-changelog` in `.pkgmeta`).

## Regenerating the data

`KeepThat/Data/` is generated and committed: one catalog and one routes file per client. To refresh it:

```
make catalog    # downloads the pinned DB2 tables to tools/.cache on first run, then rebuilds all four files
make test       # the data tests run as part of the tests
```

To use a newer game build, change `BUILDS` at the top of `tools/build-catalog.py`, run `make catalog`, review the diff, and update the builds table in `THIRD_PARTY.md`. The data formats and how to edit the endgame lists and routes are in [data.md](data.md).

