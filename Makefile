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

## mcp: start a long-lived editor with the MCP server, in the background
##   This is the one that changes how the project is worked on. UE 5.8 ships Epic's experimental
##   Model Context Protocol plugin: an MCP server inside the editor process. With it up, an agent
##   queries and drives a RUNNING editor over http://127.0.0.1:$(MCP_PORT)$(MCP_PATH) instead of
##   cold-starting one per change -- which costs a shader compile every time and was most of the
##   friction in this project's first night.
##
##   .mcp.json points Claude Code at it. Restart Claude Code once after `make mcp` to pick it up.
MCP_PORT ?= 8000
MCP_PATH ?= /mcp

mcp: build-game ue-kill
	@mkdir -p Saved/Logs
	@nohup $(UE_EDITOR) $(PWD)/Steeplejack.uproject $(MAP) \
		-RenderOffscreen -nosplash -NoSound > Saved/Logs/mcp-editor.log 2>&1 &
	@printf "  starting editor"
	@for i in $$(seq 1 60); do \
		if ss -ltn 2>/dev/null | grep -q ":$(MCP_PORT)"; then echo; \
		  echo "  MCP up on http://127.0.0.1:$(MCP_PORT)$(MCP_PATH)"; \
		  grep -E "SJTOOLS" Saved/Logs/Steeplejack.log 2>/dev/null | tail -1; exit 0; fi; \
		printf "."; sleep 2; \
	done; \
	echo; echo "  MCP did not come up — see Saved/Logs/mcp-editor.log"; exit 1

## mcp-status: is the editor up and serving tools?
mcp-status:
	@ss -ltn 2>/dev/null | grep -q ":$(MCP_PORT)" \
		&& echo "  MCP listening on 127.0.0.1:$(MCP_PORT)$(MCP_PATH)" \
		|| (echo "  not running — \`make mcp\`"; exit 1)
	@$(PY) tools/mcp_call.py list_toolsets 2>/dev/null || true

## mcp-stop: shut the editor down
mcp-stop: ue-kill
	@echo "  editor stopped"

## materials: build the band material (run once; build-map needs it)
materials:
	@$(MAKE) --no-print-directory ue-py SCRIPT=tools/editor/make_materials.py

## build-map: (re)generate the test map from tools/editor/build_test_map.py
##   Removes the .umap first: LevelEditorSubsystem.new_level() returns False if the asset exists,
##   and the save that follows then reports success while writing nothing.
build-map:
	@rm -f Content/Maps/ShotTest.umap
	@$(MAKE) --no-print-directory ue-py SCRIPT=tools/editor/build_test_map.py

## play: build, run the game headless, and write a screenshot you can actually look at
##   The one that matters. If you changed something visual and have not looked at a frame,
##   you have not finished. Writes Saved/Screenshots/LinuxEditor/*.png.
play: build-game
	@rm -f Saved/Screenshots/LinuxEditor/*.png
	@timeout $(PLAY_SECS) $(UE_EDITOR) $(PWD)/Steeplejack.uproject $(MAP) -game -RenderOffscreen \
	  -unattended -nosplash -NoSound -windowed -ResX=1280 -ResY=720 \
	  -ExecCmds="$(PLAY_CMDS)" >/dev/null 2>&1 || true
	@$(MAKE) --no-print-directory ue-kill
	@ls -1 Saved/Screenshots/LinuxEditor/*.png 2>/dev/null \
	  && echo "  ^ open these" \
	  || (echo "  no screenshot — see Saved/Logs/Steeplejack.log"; exit 1)

## build-game: compile the UE game module
# A build must always produce the binary that the next run loads. If an editor is live — and the
# session-start MCP hook keeps one live — UBT quietly falls back to a *hot-reload* build: it writes
# libUnrealEditor-SteeplejackGame-0001.so and leaves the base .so untouched, so `make play` then
# launches yesterday's code and reports success. Kill the editor first and sweep the numbered
# leftovers, so "it built" and "it ran" cannot disagree. Restart the live editor with `make mcp`.
build-game: ue-kill
	@rm -f Binaries/Linux/libUnrealEditor-SteeplejackGame-[0-9][0-9][0-9][0-9].so \
	       Binaries/Linux/libUnrealEditor-SteeplejackSim-[0-9][0-9][0-9][0-9].so
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

## run: play the game in a window, on your screen, with a keyboard
##   This is the one you want. `make play` is the headless one: it renders a frame to a PNG and
##   exits, which is what CI and an agent need and is no use to a human.
run: build-game ue-kill
	@echo "  opening $(MAP) — close the window or press Esc to quit"
	@$(UE_EDITOR) $(PWD)/Steeplejack.uproject $(MAP) -game \
		-windowed -ResX=1600 -ResY=900 -NoSound

## editor: open the Unreal editor on the test map
editor: build-game ue-kill
	@$(UE_EDITOR) $(PWD)/Steeplejack.uproject $(MAP)

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
        play run build-map materials ue-py ue-kill mcp mcp-status mcp-stop \
        wt-start wip wt-status land wt-drop doctor

# ---------------------------------------------------------------- Godot
GODOT ?= $(firstword $(wildcard $(HOME)/.local/bin/godot /usr/bin/godot) godot)
GODOT_CPP_REF ?= master
# Must match the engine in $(GODOT). godot-cpp master ships API files for 4.3 through 4.7; picking
# the one that matches is what stops the extension and the editor disagreeing about the ABI.
GODOT_API_VERSION ?= 4.7
# godot-cpp links libstdc++ statically by default, for portable shipping binaries. On an immutable
# host there is no static libstdc++ to link against and the error only says "have you installed the
# static version of the stdc++ library?". Off for local builds; a shipping build turns it back on.
GODOT_STATIC_CPP ?= OFF

godot-deps:
	@test -d .deps/godot-cpp || git clone --depth 1 --branch $(GODOT_CPP_REF) \
	  https://github.com/godotengine/godot-cpp.git .deps/godot-cpp
	@echo "godot-cpp ready at .deps/godot-cpp"

godot-build: godot-deps
	@cmake -S . -B build-godot -DSTEEPLEJACK_GODOT=ON -DCMAKE_BUILD_TYPE=Release -DGODOTCPP_API_VERSION=$(GODOT_API_VERSION) -DGODOTCPP_USE_STATIC_CPP=$(GODOT_STATIC_CPP) >/dev/null
	@cmake --build build-godot --target steeplejack_gd -j$$(nproc)
	@ls -la godot/bin/

# Open the editor.
godot-editor: godot-import
	@$(GODOT) --path godot --editor

# Run the game in a window. Builds first, so a fresh clone is one command away from playing.
godot-run: godot-build godot-import
	@$(GODOT) --path godot

# Run a script headlessly against the project — the Godot equivalent of `make ue-py`, and the
# way anything gets verified without a human watching.
#   make godot-script SCRIPT=res://scripts/prove_sim.gd
# A project Godot has never opened has no .godot/ and therefore no registered extensions, and the
# only symptom is "Identifier not declared" from GDScript. Import first, every time; it is fast
# once the cache exists.
godot-import:
	@$(GODOT) --path godot --headless --import >/dev/null 2>&1 || true

godot-script: godot-import
	@test -n "$(SCRIPT)" || (echo "usage: make godot-script SCRIPT=res://scripts/foo.gd" && exit 1)
	@$(GODOT) --path godot --headless --script $(SCRIPT)

# The playable build's own regression tests. Godot cannot render headlessly, so these drive nodes
# directly and assert on state — no substitute for playing it, but a substitute for shipping the
# same bug twice.
## shot: pose the jack and photograph him — the Godot answer to `make play`
##
## Godot's --headless has no renderer at all. Under a virtual X display it renders fine, software
## rasterised, a few seconds a frame. Before this, every visual change in this engine was shipped
## without anyone having looked at a frame of it.
##
##   make shot
##   make shot CMDS="climb 26,shot at-26m"
##   make shot CMDS="carry,dog 20,climb 21,work,shot dogging-in"
##
## See the command vocabulary at the top of godot/scripts/shot.gd.
CMDS ?=
SHOT_RES ?= 1600x900
shot: godot-build godot-import
	@command -v xvfb-run >/dev/null || (echo "shot needs xvfb-run (package xorg-x11-server-Xvfb)" && exit 1)
	@timeout 600 xvfb-run -a -s "-screen 0 $(SHOT_RES)x24" \
		$(GODOT) --path godot --resolution $(SHOT_RES) --script res://scripts/shot.gd -- $(CMDS) \
		2>&1 | grep -vE "^(WARNING|MESA|Note:|     at:)" || true

## godot-test: drive the real scene headlessly and assert on state
##
## Bounded, because a parse error in any .gd file makes one of these hang for ever rather than
## fail: the scene never loads, the script never reaches its quit(), and the run just sits there.
## A gate that hangs is worse than a gate that fails, because nobody reads a hang as a result.
godot-test: godot-build godot-import
	@for t in test_ladder test_character test_slip test_stance; do \
		timeout 120 $(GODOT) --path godot --headless --script res://scripts/$$t.gd; \
		rc=$$?; \
		if [ $$rc -eq 124 ]; then \
			printf '\033[31mFAILED\033[0m  %s hung for 120 s and was killed.\n' "$$t"; \
			printf '        Almost always a GDScript parse error — the scene never loads, so the\n'; \
			printf '        script never reaches quit(). The parse error is printed above.\n'; \
			exit 1; \
		elif [ $$rc -ne 0 ]; then \
			exit $$rc; \
		fi; \
	done

.PHONY: godot-deps godot-build godot-import godot-test godot-editor godot-run godot-script
