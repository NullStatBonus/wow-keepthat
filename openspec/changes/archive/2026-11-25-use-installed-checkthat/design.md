# Design

## Decisions

- **`ct` from PATH, overridable.** `make plan` uses `CT ?= ct`, the launcher `make install-skill BIN_DIR=$HOME/bin` links. Without `BIN_DIR`, `make plan CT=~/.claude/skills/ct-test-plan/ct/tools/ct` works. No file points at a checkout.
- **`make plan` is the whole offline gate.** The AGENTS.md rule lists validate, compile, replay-flow, lines and offline; one target runs them in that order and stops at the first failure. It stays out of `make test` and `make check`, because CI has no CheckThat.
- **`replay-flow` proves the flow, `lines` proves the source.** With no hooks file the replay writes the lines and facts each step expects ("evidence assumed": 21 checks on Forever, 14 on Classic Era). That checks the plan, not KeepThat. `ct lines --addon-src KeepThat` checks that the source writes each asserted line and fact key (25 found, 0 missing). The hand-written hooks file did the same job by copying the wording, so it is redundant.
- **Gaps allowed in ids.** The old test demanded contiguous numbers, so removing a step meant renumbering the next ones, which cut `kt.s1.2`'s history. The test now demands unique, strictly increasing numbers. "Test plan N.M" references still have to resolve.
- **`offline.toc` keeps `wow-keepthat/KeepThat/KeepThat_Vanilla.toc`.** CheckThat reads it inside `--addons`, by default the folder above the repository (`docs/authoring-plans.md`). `KeepThat/KeepThat_Vanilla.toc` fails there. The path depends on the clone's folder name; that is CheckThat's contract, not a checkout path.
- **Tasks 3.1 and 10.2 of `add-checkthat-integration`** are already ticked in the archive. The installed `ct offline plans/keepthat.yaml` passes 7 of 7 with the plan as it is, `covers:` included, so the archive stays as written.
