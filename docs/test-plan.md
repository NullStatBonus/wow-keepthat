# Test plan

The in-game test plan is [`plans/keepthat.yaml`](../plans/keepthat.yaml). [CheckThat](https://github.com/NullStatBonus/wow-checkthat) runs it in game: it shows each step, records the result and reads the debug log lines that prove it. AGENTS.md ("CheckThat") says how to change it.

"Test plan check 4.1" in the code and docs means step `kt.s4.1`; "section 4" means section `s4`. `tests/test_plan.lua` fails when such a reference names a step the plan does not have.

The plan's first step, `kt.s1.1`, checks the KeepThat version through the `version` entry; the Lua-error step is `kt.s1.2`. Steps marked `auto: true` record their result from KeepThat's debug lines, facts and entries, with no player judgment. The plan's `offline:` block calls the entries in CheckThat's fake client (`ct.py offline`); `docs/contracts.md` ("CheckThat", "Fake client limits") says what the fake client cannot load yet.

To run it, with CheckThat checked out next to this repository as `../wow-checkthat`:

1. `make plan` validates the plan and writes `build/keepthat.ct`. Then, from `../wow-checkthat`, `luajit tests/replay_plan.lua ../wow-keepthat/build/keepthat.ct ../wow-keepthat/plans/keepthat.replay.lua` plays it in CheckThat's fake client. The hooks file writes the KeepThat lines and facts each step expects, in the wording `docs/contracts.md` fixes, so a reworded line or a wrong pattern shows as a problem.
2. In game, with CheckThat installed, type `/ct import`, paste the contents of `build/keepthat.ct`, then type `/ct start KeepThat`.
3. After the run, read it back from this repository's root with `../wow-checkthat/.venv/bin/python ../wow-checkthat/tools/ct.py collect --plan plans/keepthat.yaml` (it saves to CheckThat's `evidence/` folder), or with the `/ct-verify` skill.
