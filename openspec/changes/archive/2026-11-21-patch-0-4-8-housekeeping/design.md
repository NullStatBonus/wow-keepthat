# Design

## Decisions

- **#28: track, don't reword.** `.gitignore` uses `.claude/*` with `!.claude/skills/` and `!.claude/commands/`. A plain `.claude/` rule cannot be re-included, because Git does not look inside an ignored folder. Local files such as `settings.local.json` stay ignored.
- **#26: relax the rule, don't split files.** The shared test files group tests by feature: one adapter area and the module that uses it are tested together through the same fake. Splitting them would duplicate the fakes. The rule now names the area files, so every module's tests can still be found. Generated `Data/` files count as one module, tested by `test_data.lua`.
- **#27: drop only with proof.** A manual check leaves the plan only when a named unit test asserts the same behavior, or when it needs an old version or staged history that the current rules forbid.
- **#14: no library change.** The skew the issue reported is gone. The three provenance files differ in layout but each records the same facts; aligning their layout is work in the sibling repositories.
