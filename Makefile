.PHONY: test test-lua test-py check catalog

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

# The same checks the release workflow runs.
check:
	@for toc in KeepThat/KeepThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
