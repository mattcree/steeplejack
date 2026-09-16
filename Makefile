# Steeplejack — canonical commands.
# Every verification claim in this project reduces to one of these.
# See docs/06-workflow/03-verification.md

PY      ?= python3
CMAKE   ?= cmake
UE      ?= $(UE_ROOT)/Engine/Binaries/Linux/UnrealEditor-Cmd
BUILD   ?= build
FILTER  ?=

.DEFAULT_GOAL := help

# ---------------------------------------------------------------- the gates

## check: the local gate — must stay under 60 seconds, forever
check: check-conventions validate check-links test-unit

## ci: everything CI runs without Unreal installed (gates 1-8)
ci: check test-levels test-replay test-determinism

# ---------------------------------------------------------------- fast (no engine, no cmake)

## check-conventions: sim purity, magic numbers, tuning keys, likeness denylist
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

# ---------------------------------------------------------------- sim (cmake, NO Unreal needed)
# This is the whole point of ADR-0004's module split: the layer that holds all the
# gameplay logic builds and tests in ~20 seconds with no engine installed.

## configure: configure the standalone sim build
configure:
	@$(CMAKE) -B $(BUILD) -DCMAKE_BUILD_TYPE=RelWithDebInfo

## build-sim: compile SteeplejackSim standalone
build-sim: configure
	@$(CMAKE) --build $(BUILD) -j

## test-unit: sim unit + property tests (FILTER=Stack to narrow)
test-unit: build-sim
	@if [ -x $(BUILD)/sim_tests ]; then $(BUILD)/sim_tests $(if $(FILTER),--test-case=*$(FILTER)*,); \
	else echo "  no sim tests yet — start with CORE-003"; fi

## test-levels: schema, Ascent Beat Rule and reachability for every level
test-levels: build-sim
	@if [ -x $(BUILD)/sim_tests ]; then $(BUILD)/sim_tests --test-case=*Level*,*Reachability*; \
	else $(PY) tools/validate_data.py; fi

## test-replay: recorded expert runs must reproduce their outcome
test-replay: build-sim
	@if [ -x $(BUILD)/sim_tests ]; then $(BUILD)/sim_tests --test-case=*Replay*; \
	else echo "  no replays yet — TEST-002"; fi

## test-determinism: same seed + same intents -> same state, repeatedly
test-determinism: build-sim
	@if [ -x $(BUILD)/sim_tests ]; then $(BUILD)/sim_tests --test-case=*Determinism*; \
	else echo "  no determinism tests yet — CORE-006"; fi

## test-perf: assert Sim::Step stays under 0.5 ms (no engine needed)
test-perf: build-sim
	@if [ -x $(BUILD)/sim_tests ]; then $(BUILD)/sim_tests --test-case=*Perf*; fi

## test-coverage: sim line coverage gate (>= 90%)
test-coverage:
	@$(PY) tools/coverage.py

# ---------------------------------------------------------------- engine (needs UE_ROOT)

## build-game: compile the UE game module
build-game:
	@test -n "$(UE_ROOT)" || (echo "set UE_ROOT to your Unreal 5.5 install" && exit 1)
	@$(UE_ROOT)/Engine/Build/BatchFiles/Linux/Build.sh SteeplejackEditor Linux Development \
		-project=$(PWD)/Steeplejack.uproject

## test-automation: UE automation tests (presentation layer only)
test-automation:
	@$(UE) $(PWD)/Steeplejack.uproject -ExecCmds="Automation RunTests Steeplejack; Quit" \
		-unattended -nullrhi -nosplash

## perf-capture: frame-time capture on the three reference scenes (nightly)
perf-capture:
	@$(PY) tools/perf_capture.py

## editor: open the Unreal editor
editor:
	@$(UE_ROOT)/Engine/Binaries/Linux/UnrealEditor $(PWD)/Steeplejack.uproject

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

## editor-queue: tasks that need a human in the Unreal editor
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

## install-hooks: install the pre-commit hook
install-hooks:
	@printf '#!/bin/sh\nexec make check-conventions validate check-links\n' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "installed .git/hooks/pre-commit"

## help: this list
help:
	@grep -hE '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | \
		awk -F: '{printf "  \033[36m%-20s\033[0m%s\n", $$1, $$2}'

.PHONY: check ci check-conventions validate validate-data validate-tasks check-links \
        configure build-sim test-unit test-levels test-replay test-determinism test-perf \
        test-coverage build-game test-automation perf-capture editor \
        board ready waves critical editor-queue stale graph new-task install-hooks help
