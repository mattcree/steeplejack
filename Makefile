# Steeplejack — canonical commands.
# Every verification claim in this project reduces to one of these.
# See docs/06-workflow/03-verification.md

PY      ?= python3
CMAKE   ?= cmake
# Where Unreal 5.8 lives. You should not have to set this.
#
# Order: whatever is already in your environment or on the command line, then Makefile.local
# (gitignored — put `UE_ROOT = /path/to/UE_5.8` there if yours is somewhere unusual), then the
# places it is normally installed. `make ue-root` prints what was found.
-include Makefile.local
UE_ROOT ?= $(firstword $(wildcard \
             $(HOME)/UnrealEngine/UE_5.8 \
             $(HOME)/UnrealEngine/UE_5.8.2 \
             /opt/UnrealEngine/UE_5.8 \
             /usr/local/UnrealEngine/UE_5.8))
UE      ?= $(UE_ROOT)/Engine/Binaries/Linux/UnrealEditor-Cmd
UE_EDITOR ?= $(UE_ROOT)/Engine/Binaries/Linux/UnrealEditor
BUILD   ?= build
FILTER  ?=
comma   := ,

# `make play` knobs. MAP is what to open; PLAY_CMDS is what to do once it is open.
MAP       ?= /Game/Maps/ShotTest
PLAY_CMDS ?= shot showui
PLAY_SECS ?= 180

.DEFAULT_GOAL := help

# ---------------------------------------------------------------- the gates

## check: the local gate — must stay under 60 seconds, forever
check: check-conventions validate check-links test-unit

## ci: everything CI runs without Unreal installed (gates 1-8)
ci: check check-verify test-tools check-blueprints test-levels test-replay test-determinism

# ---------------------------------------------------------------- fast (no engine, no cmake)

## check-conventions: sim purity, magic numbers, tuning keys, likeness denylist
check-conventions:
	@$(PY) tools/check_conventions.py

## watch: run the sim and print what it is doing (no engine, no GPU) — TOOL-001
##   Not a test and not a gate: it asserts nothing and `make check` must not depend on it.
watch: build-sim
	@$(CXX) -std=c++20 -O2 -Wall -Wextra -Wconversion -Werror -ISource/SteeplejackSim/Public \
		tools/sim_watch.cpp -L$(BUILD) -lsteeplejack_sim -o $(BUILD)/sim_watch
	@$(BUILD)/sim_watch

## test-tools: the checkers and the worktree tool have tests (rule: no untested rules)
test-tools:
	@$(PY) tools/test_conventions.py
	@$(PY) tools/test_wt.py
	@$(PY) tools/test_check_verify.py

## check-verify: every task's verify: filter points at tests that exist
check-verify: build-sim
	@$(PY) tools/check_verify.py

## check-blueprints: rule 18 — Blueprints are glue only
check-blueprints:
	@$(PY) tools/check_blueprints.py

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

## test-unit: sim unit + property tests (FILTER=rng to narrow)
##
## A FILTER matching zero test cases exits NON-ZERO. Nearly every task's `verify:`
## runs through here, so a filter that silently matches nothing is a task that can be
## handed off, reviewed and landed with its stated verification never having executed.
## See TEST-003. Unfiltered runs are unchanged, which is what keeps `make check` green
## on a fresh clone where most modules do not exist yet.
test-unit: build-sim
	@if [ ! -x $(BUILD)/sim_tests ]; then echo "  no sim tests yet — start with CORE-003"; exit 0; fi; \
	if [ -z "$(FILTER)" ]; then $(BUILD)/sim_tests; exit $$?; fi; \
	count() { $(BUILD)/sim_tests $$1 --list-test-cases 2>/dev/null \
	          | sed -n 's/.*passing the current filters: \([0-9]*\).*/\1/p'; }; \
	n=$$(count "--test-case=*$(FILTER)*"); n=$${n:-0}; \
	all=$$(count ""); all=$${all:-0}; \
	if [ "$$n" -eq 0 ]; then \
		printf '\033[31mFAILED\033[0m  FILTER=%s matched 0 of %s test cases — nothing ran.\n' \
		       '$(FILTER)' "$$all"; \
		printf '        A gate that runs nothing must not report success (TEST-003).\n'; \
		printf '        Either this task'"'"'s tests do not exist yet, or the filter is wrong:\n'; \
		printf '        doctest matches TEST_CASE *names*, not file names.\n'; \
		printf '        Names in the binary start with: %s\n' \
		       "$$($(BUILD)/sim_tests --list-test-cases 2>/dev/null \
		          | sed -n 's/^\([A-Za-z0-9_]*\):.*/\1/p' | sort -u | tr '\n' ' ')"; \
		exit 1; \
	fi; \
	$(BUILD)/sim_tests "--test-case=*$(FILTER)*"

# A filtered gate that matches zero test cases must NOT report success — that is how a
# suite rots into decoration. gate() prints an explicit "not yet meaningful" instead.
# $(1)=doctest filter  $(2)=human name  $(3)=the task that makes it real
define gate
	@n=$$($(BUILD)/sim_tests --test-case=$(1) --list-test-cases 2>/dev/null \
	      | sed -n 's/.*passing the current filters: \([0-9]*\).*/\1/p'); \
	n=$${n:-0}; \
	if [ "$$n" -eq 0 ]; then \
		printf '  \033[33m--\033[0m %s: no such tests yet (lands in %s)\n' "$(2)" "$(3)"; \
	else \
		$(BUILD)/sim_tests --test-case=$(1); \
	fi
endef

## test-levels: schema, Ascent Beat Rule and reachability for every level
test-levels: build-sim validate-data
	$(call gate,*Level*$(comma)*Reachability*,level validation,CORE-008/CORE-009)

## test-replay: recorded expert runs must reproduce their outcome
test-replay: build-sim
	$(call gate,*Replay*,replay regression,CORE-006/TEST-002)

## test-determinism: same seed + same intents -> same state, repeatedly
test-determinism: build-sim
	$(call gate,*Determinism*,determinism,CORE-003/CORE-006)

## test-perf: assert Sim::Step stays under 0.5 ms (no engine needed)
test-perf: build-sim
	$(call gate,*Perf*,sim step budget,CORE-005)

## test-coverage: sim line coverage gate (>= 90%)
test-coverage:
	@$(PY) tools/coverage.py

# ---------------------------------------------------------------- engine (needs UE_ROOT)

## ue-root: print the Unreal install this Makefile will use
ue-root:
	@if [ -n "$(UE_ROOT)" ]; then echo "UE_ROOT = $(UE_ROOT)"; \
	else echo "no Unreal found. Put 'UE_ROOT = /path/to/UE_5.8' in Makefile.local, or pass UE_ROOT=..."; exit 1; fi

# Unreal holds an exclusive lock on the project. A previous editor still running makes the next
# run exit silently having done nothing, which looks exactly like a script that did not work.
# Every editor target kills stragglers first. Learned the hard way.
ue-kill:
	@pkill -x UnrealEditor 2>/dev/null || true
	@pkill -x UnrealEditor-Cmd 2>/dev/null || true
	@for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "Binaries/Linux/UnrealEditor" >/dev/null 2>&1 || break; sleep 1; done

## ue-py: run a python script in the editor, headless.  make ue-py SCRIPT=tools/editor/foo.py
ue-py: ue-kill
	@test -n "$(UE_ROOT)" || (echo "no Unreal found — see \`make ue-root\`" && exit 1)
	@test -n "$(SCRIPT)" || (echo "usage: make ue-py SCRIPT=tools/editor/foo.py" && exit 1)
	@timeout 900 $(UE) $(PWD)/Steeplejack.uproject -run=pythonscript \
	  -script=$(PWD)/$(SCRIPT) -unattended -nosplash -NoSound >/dev/null 2>&1 || true
	@grep -E "^\[.*LogPython: (Error: )?SJ" Saved/Logs/Steeplejack.log | sed 's/.*LogPython: //' || \
	  echo "  no SJ* output — see Saved/Logs/Steeplejack.log"

## build-map: (re)generate the test map from tools/editor/build_test_map.py
##   Removes the .umap first: LevelEditorSubsystem.new_level() returns False if the asset exists,
##   and the save that follows then reports success while writing nothing.
build-map:
	@rm -f Content/Maps/ShotTest.umap
	@$(MAKE) --no-print-directory ue-py SCRIPT=tools/editor/build_test_map.py

## play: build, run the game headless, and write a screenshot you can actually look at
##   The one that matters. If you changed something visual and have not looked at a frame,
##   you have not finished. Writes Saved/Screenshots/LinuxEditor/*.png.
play: build-game ue-kill
	@rm -f Saved/Screenshots/LinuxEditor/*.png
	@timeout $(PLAY_SECS) $(UE_EDITOR) $(PWD)/Steeplejack.uproject $(MAP) -game -RenderOffscreen \
	  -unattended -nosplash -NoSound -windowed -ResX=1280 -ResY=720 \
	  -ExecCmds="$(PLAY_CMDS)" >/dev/null 2>&1 || true
	@$(MAKE) --no-print-directory ue-kill
	@ls -1 Saved/Screenshots/LinuxEditor/*.png 2>/dev/null \
	  && echo "  ^ open these" \
	  || (echo "  no screenshot — see Saved/Logs/Steeplejack.log"; exit 1)

## build-game: compile the UE game module
build-game:
	@test -n "$(UE_ROOT)" || (echo "no Unreal 5.8 found. Put 'UE_ROOT = /path/to/UE_5.8' in Makefile.local (gitignored), or pass UE_ROOT=... — \`make ue-root\` shows what was detected" && exit 1)
	@$(UE_ROOT)/Engine/Build/BatchFiles/Linux/Build.sh SteeplejackEditor Linux Development \
		-project=$(PWD)/Steeplejack.uproject

## test-automation: in-engine tests — the sim running inside Unreal, and the actors built from data
##   These are NOT a second copy of `make check`. They test what only the engine can tell you:
##   that the sim links and behaves inside UE, and that an actor built from a level file contains
##   the geometry that file describes.
test-automation: build-game ue-kill
	@timeout 600 $(UE) $(PWD)/Steeplejack.uproject \
		-ExecCmds="Automation RunTests Steeplejack; Quit" \
		-unattended -nullrhi -nosplash -NoSound >/dev/null 2>&1 || true
	@$(MAKE) --no-print-directory ue-kill
	@grep -E "LogAutomationController.*(Test Completed|Success|Fail)" Saved/Logs/Steeplejack.log \
		| sed 's/.*LogAutomationController: //' | tail -20 || true
	@if grep -qE "LogAutomationController.*Fail" Saved/Logs/Steeplejack.log; then \
		echo "  FAILED — see Saved/Logs/Steeplejack.log"; exit 1; \
	fi

## perf-capture: frame-time capture on the three reference scenes (nightly)
perf-capture:
	@$(PY) tools/perf_capture.py

## editor: open the Unreal editor
editor:
	@$(UE_ROOT)/Engine/Binaries/Linux/UnrealEditor $(PWD)/Steeplejack.uproject

# ---------------------------------------------------------------- parallel work
# Parallel generation, sequential merging. See docs/06-workflow/07-integration.md

## wt-start: claim a task in an isolated worktree — make wt-start ID=CORE-003
wt-start:
	@$(PY) tools/wt.py start $(ID)

## wip: commit everything and push. The panic button. Run it constantly.
wip:
	@$(PY) tools/wt.py save "$(M)"

## wt-status: every worktree, and exactly what is not yet safe
wt-status:
	@$(PY) tools/wt.py status

## land: the merge queue — backup, rebase, verify, merge. One task at a time.
land:
	@$(PY) tools/wt.py land $(ID)

## wt-drop: remove a worktree, refusing if anything would be lost
wt-drop:
	@$(PY) tools/wt.py drop $(ID)

## doctor: find work that exists only on this disk
doctor:
	@$(PY) tools/wt.py doctor

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

## human-queue: ALL work a human must do — editor, recording, playtests
human-queue:
	@$(PY) tools/tasks.py human

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
        board ready waves critical editor-queue human-queue stale graph new-task \
        test-tools check-verify check-blueprints install-hooks help watch ue-root \
        play build-map ue-py ue-kill \
        wt-start wip wt-status land wt-drop doctor
