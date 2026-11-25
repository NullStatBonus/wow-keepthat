.PHONY: test test-lua test-py check catalog plan

test: test-lua test-py

# luajit tests/run.lua [pattern] runs a subset, e.g. luajit tests/run.lua core
test-lua:
	@luajit tests/run.lua

test-py:
	@PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools -p 'test_*.py'

# Regenerate both clients' catalogs (downloads DB2 tables to tools/.cache on first run).
catalog:
	@python3 tools/build-catalog.py --client era
	@python3 tools/build-catalog.py --client forever
	@python3 tools/build-routes.py --client era
	@python3 tools/build-routes.py --client forever

# The checks before a tester runs the in-game test plan, with the installed CheckThat tools: validate, compile to
# build/keepthat.ct, replay-flow, lines and offline. Install them once with `make install-skill BIN_DIR=$$HOME/bin`
# in CheckThat (its docs/skills.md), or set CT=<path to ct>. Not part of test or check: CI has no CheckThat.
CT ?= ct
PLAN := plans/keepthat.yaml
plan:
	@command -v "$(CT)" >/dev/null 2>&1 || { echo "plan: no CheckThat tools ($(CT) not found); install them with make install-skill BIN_DIR=\$$HOME/bin in CheckThat, or set CT=<path to ct>" >&2; exit 1; }
	@mkdir -p build
	@"$(CT)" validate $(PLAN)
	@"$(CT)" compile $(PLAN) -o build/keepthat.ct
	@"$(CT)" replay-flow $(PLAN)
	@"$(CT)" lines $(PLAN) --addon-src KeepThat
	@"$(CT)" offline $(PLAN)

# The same checks the release workflow runs.
check:
	@for toc in KeepThat/KeepThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
