# Test plan

The in-game test plan is [`plans/keepthat.yaml`](../plans/keepthat.yaml). [CheckThat](https://github.com/NullStatBonus/wow-checkthat) runs it in game: it shows each step, records the result and reads the debug log lines that prove it. AGENTS.md ("CheckThat") says how to change it.

"Test plan check 4.1" in the code and docs means step `kt.s4.1`; "section 4" means section `s4`. `tests/test_plan.lua` fails when such a reference names a step the plan does not have.

The plan's first step, `kt.s1.1`, checks the KeepThat version through the `version` entry; the Lua-error step is `kt.s1.2`. Steps marked `auto: true` record their result from KeepThat's debug lines, facts and entries, with no player judgment. The plan's `offline:` block calls the entries in CheckThat's fake client (`ct offline`); `docs/contracts.md` ("CheckThat", "Fake client limits") says what the fake client cannot load yet.

To run it, with the CheckThat skills installed (`make install-skill BIN_DIR=$HOME/bin` in the CheckThat checkout, so `ct` is on your PATH):

1. `make plan` validates the plan, writes `build/keepthat.ct`, plays it in CheckThat's fake client on both clients (`ct replay-flow`), checks that KeepThat's source writes every line and fact the plan asserts (`ct lines --addon-src KeepThat`), and runs the `offline:` block (`ct offline`). The replay writes the lines each step expects itself, so it checks the plan flow; `ct lines` checks the wording against the code.
2. In game, with CheckThat installed, type `/ct import`, paste the contents of `build/keepthat.ct`, then type `/ct start KeepThat`.
3. After the run, read it back from this repository's root with `ct collect --plan plans/keepthat.yaml` (it saves to `evidence/`, which Git ignores), or with the `/ct-verify` skill.
