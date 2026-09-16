# Steeplejack — canonical commands.
# Every verification claim in this project reduces to one of these.
# See docs/06-workflow/03-verification.md

GODOT  ?= godot
PY     ?= python3
FILTER ?=

.DEFAULT_GOAL := help

# ---------------------------------------------------------------- the gates

## check: the local gate — must stay under 30 seconds, forever
check: lint check-conventions validate check-links test-unit

## ci: everything CI runs (gates 1-8)
ci: check test-levels test-replay test-determinism

# ---------------------------------------------------------------- fast (no engine)

## lint: gdformat + gdlint over sim/, game/ and tests/
lint:
	@command -v gdformat >/dev/null 2>&1 && gdformat --check sim game tests || \
		echo "  (gdtoolkit not installed — pip install gdtoolkit; skipping)"
	@command -v gdlint   >/dev/null 2>&1 && gdlint sim game tests || \
		echo "  (gdtoolkit not installed — skipping)"

## check-conventions: sim/ purity, no magic numbers, tuning keys, likeness denylist
check-conventions:
	@$(PY) tools/check_conventions.py

## validate: level + tuning data, and the task graph
validate: validate-data validate-tasks

validate-data:
	@$(PY) tools/validate_data.py

## validate-tasks: frontmatter, dependency graph, ownership conflicts, spec refs
validate-tasks:
	@$(PY) tools/tasks.py validate

## check-links: every relative link in the docs resolves
check-links:
	@$(PY) tools/check_links.py

# ---------------------------------------------------------------- engine

## test-unit: sim/ unit and property tests (FILTER=test_foo to narrow)
test-unit:
	@$(GODOT) --path . --headless -s tests/run_tests.gd -- --filter="$(FILTER)"

## test-levels: schema, Ascent Beat Rule and reachability for every level
test-levels:
	@$(GODOT) --path . --headless -s tests/validate_levels.gd

## test-replay: recorded expert runs must reproduce their outcome
test-replay:
	@$(GODOT) --path . --headless -s tests/replay/regression.gd

## test-determinism: same seed + same intents -> same state, repeatedly
test-determinism:
	@$(GODOT) --path . --headless -s tests/determinism.gd

## test-coverage: sim/ line coverage gate (>= 90%)
test-coverage:
	@$(PY) tools/coverage.py

## test-perf: frame-time capture on the three reference scenes (nightly)
test-perf:
	@$(GODOT) --path . --headless -s tests/perf/reference_scene.gd

## record: re-record an expert replay — make record LEVEL=00-greybox
record:
	@$(GODOT) --path . -- --record=$(LEVEL)

## run: launch the game
run:
	@$(GODOT) --path .

# ---------------------------------------------------------------- work items

## board: task status by milestone
board:
	@$(PY) tools/tasks.py board

## ready: tasks whose dependencies are all done — claim one of these
ready:
	@$(PY) tools/tasks.py ready

## waves: dependency-ordered execution waves for parallel planning
waves:
	@$(PY) tools/tasks.py waves

## critical: the longest dependency chain — make critical TARGET=PT-001
critical:
	@$(PY) tools/tasks.py critical $(TARGET)

## editor-queue: tasks that need a human in the Godot editor
editor-queue:
	@$(PY) tools/tasks.py editor

## stale: in_progress tasks with no plan and no outcome
stale:
	@$(PY) tools/tasks.py stale

## graph: mermaid dependency graph
graph:
	@$(PY) tools/tasks.py graph

## new-task: make new-task ID=CLIMB-012 TITLE="Ladder condition wear"
new-task:
	@$(PY) tools/tasks.py new $(ID) "$(TITLE)"

# ---------------------------------------------------------------- setup

## install-hooks: install the pre-commit hook (gates 1-3)
install-hooks:
	@printf '#!/bin/sh\nexec make check-conventions validate check-links\n' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "installed .git/hooks/pre-commit"

## help: this list
help:
	@grep -hE '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | \
		awk -F: '{printf "  \033[36m%-20s\033[0m%s\n", $$1, $$2}'

.PHONY: check ci lint check-conventions validate validate-data validate-tasks check-links \
        test-unit test-levels test-replay test-determinism test-coverage test-perf record run \
        board ready waves critical editor-queue stale graph new-task install-hooks help
