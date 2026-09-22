# Steeplejack — canonical commands.
# Every verification claim in this project reduces to one of these.
# See docs/06-workflow/03-verification.md

PY      ?= python3
CMAKE   ?= cmake
BUILD   ?= build
FILTER  ?=
comma   := ,

.DEFAULT_GOAL := help

# ---------------------------------------------------------------- the gates

## check: the local gate — must stay under 60 seconds, forever
check: check-conventions validate check-links check-assets test-unit

## ci: everything CI runs (gates 1-8)
ci: check check-verify test-tools test-levels test-replay test-determinism

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
	@$(PY) tools/test_content_size.py

## check-verify: every task's verify: filter points at tests that exist
check-verify: build-sim
	@$(PY) tools/check_verify.py

## validate: level + tuning data, and the task graph
validate: validate-data validate-tasks

validate-data:
	@$(PY) tools/validate_data.py

## validate-tasks: frontmatter, dependency graph, ownership conflicts, spec refs
validate-tasks:
	@$(PY) tools/tasks.py validate

## check-assets: every binary goes through LFS, and none of them is enormous — CORE-010
##
## Binary is the half of this project agents cannot author or review. This is what stops that
## arrangement rotting: an undeclared extension is stored raw in every clone for ever, and getting
## it back out means rewriting history.
check-assets:
	@$(PY) tools/check_content_size.py

## check-links: every relative link in the docs resolves
check-links:
	@$(PY) tools/check_links.py

# ---------------------------------------------------------------- sim (cmake, no engine)
# The layer that holds all the gameplay logic builds and tests in seconds with no engine
# installed. The Godot game links the same library.

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

## test-replay: the replay format round-trips, and the Grey Box climb matches its recording
##   The second half needs Godot. Without it, it says so and fails — a regression gate that
##   quietly does not run is the thing this project keeps finding and removing.
test-replay: test-replay-format
	@$(MAKE) --no-print-directory replay-regression

## test-replay-format: just the replay format's round trip — no Godot, so CI's sim job can run it
test-replay-format: build-sim
	$(call gate,*Replay*,replay format,CORE-006)

replay-regression: godot-build godot-import
	@out=$$(timeout 300 $(GODOT) --path godot --headless --fixed-fps 60 \
		--script res://scripts/ascent_regression.gd 2>&1); rc=$$?; \
		echo "$$out" | grep -E "REPLAY|FAIL|^          |make record" || true; \
		if [ $$rc -eq 124 ]; then echo "  replay-regression hung (parse error, or the bot stuck)"; fi; \
		exit $$rc

## record: re-record the Grey Box climb that test-replay compares against (LEVEL=00-greybox)
##   Run it when a change is *meant* to alter the climb, and put the diff test-replay printed
##   in the commit message: the diff is the justification.
record: godot-build godot-import
	@test "$(or $(LEVEL),00-greybox)" = "00-greybox" || (echo "only 00-greybox has a recorded climb" && exit 1)
	@mkdir -p data/replays
	@out=$$(timeout 300 $(GODOT) --path godot --headless --fixed-fps 60 \
		--script res://scripts/ascent_regression.gd -- --record 2>&1); rc=$$?; \
		echo "$$out" | grep -E "REPLAY|FAIL" || true; exit $$rc

## test-determinism: same seed + same intents -> same state, repeatedly
test-determinism: build-sim
	$(call gate,*Determinism*,determinism,CORE-003/CORE-006)

## test-perf: assert Sim::Step stays under 0.5 ms (no engine needed)
test-perf: build-sim
	$(call gate,*Perf*,sim step budget,CORE-005)

## test-coverage: sim line coverage gate (>= 90%)
test-coverage:
	@$(PY) tools/coverage.py

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

## editor-queue: tasks that need a human at an editor
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
        test-coverage \
        board ready waves critical editor-queue human-queue stale graph new-task \
        test-tools check-verify install-hooks help watch run replay-regression record test-replay-format character \
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

## run: play the game in a window. Builds first, so a fresh clone is one command away from playing.
run: godot-run

godot-run: godot-build godot-import
	@$(GODOT) --path godot $(if $(LEVEL),-- --level $(LEVEL),)

## fell: play the demolition mode — cut the gob, prop it, peg the line, light it
##
##   hold LMB cut a cell   RMB stand a prop   B plumb   P pegs   hold F pack   L light   X a board
##
## Skips the board, and skips the strip-out with it — a felling from the board is two visits, and
## this one is for looking at the gob.
##   A/D walk round the base   W/S in and out   mouse look   Esc free the mouse
fell: godot-build godot-import
	@$(GODOT) --path godot res://scenes/felling.tscn --stripped $(if $(LEVEL),--level $(LEVEL),)

# Run a script headlessly against the project — the way anything gets verified without a human
# watching.
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
## shot: pose the jack and photograph him
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
LEVEL ?=
SHOT_RES ?= 1600x900
shot: godot-build godot-import
	@command -v xvfb-run >/dev/null || (echo "shot needs xvfb-run (package xorg-x11-server-Xvfb)" && exit 1)
	@timeout 600 xvfb-run -a -s "-screen 0 $(SHOT_RES)x24" \
		$(GODOT) --path godot --audio-driver Dummy --resolution $(SHOT_RES) --fixed-fps 60 --script res://scripts/shot.gd -- $(CMDS) \
		$(if $(LEVEL),--level $(LEVEL),) \
		2>&1 | grep -vE "^(WARNING|MESA|Note:|     at:)" || true

## ui-shot: photograph a menu — the board, the van, the yard, the shed, the ending
##
##   make ui-shot SCENE=res://scenes/jobs.tscn CMDS="enter,shot the-van"
##   make ui-shot SCENE=res://scenes/yard.tscn CMDS="down,down,enter,shot the-shed"
##
## See the command vocabulary at the top of godot/scripts/ui_shot.gd. It spends a tin of its own,
## never the player's.
UI_SCENE ?= res://scenes/yard.tscn
ui-shot: godot-build godot-import
	@command -v xvfb-run >/dev/null || (echo "ui-shot needs xvfb-run (package xorg-x11-server-Xvfb)" && exit 1)
	@mkdir -p docs/shots
	@xvfb-run -a --server-args="-screen 0 $(SHOT_RES)x24" \
		$(GODOT) --path godot --audio-driver Dummy --resolution $(SHOT_RES) --fixed-fps 60 \
		--script res://scripts/ui_shot.gd -- --scene $(UI_SCENE) "$(CMDS)" \
		2>&1 | grep -E "wrote|UI-SHOT|ui-shot:|SCRIPT ERROR|Parse Error" || true

## fell-shot: render the felling mode to a PNG. CMDS="cut 160,shot gob"
##
## Same software renderer as `make shot`. A felling is almost entirely a thing you look at, so
## this is the gate on whether the gob, the props and the plan view actually read.
fell-shot: godot-build godot-import
	@command -v xvfb-run >/dev/null || (echo "fell-shot needs xvfb-run (package xorg-x11-server-Xvfb)" && exit 1)
	@timeout 600 xvfb-run -a -s "-screen 0 $(SHOT_RES)x24" \
		$(GODOT) --path godot --audio-driver Dummy --resolution $(SHOT_RES) --fixed-fps 60 --script res://scripts/fell_shot.gd $(if $(LEVEL),--level $(LEVEL),) -- $(CMDS) \
		2>&1 | grep -vE "^(WARNING|MESA|Note:|     at:)" || true

## character: rebuild the steeplejack — model, rig and clips — from tools/blender/build_character.py
##   Blender is run headless; the script is the source and the .glb is its output. Commit both.
BLENDER ?= $(or $(shell command -v blender 2>/dev/null),flatpak run org.blender.Blender)
character:
	@out=$$($(BLENDER) --background --factory-startup --python $(PWD)/tools/blender/build_character.py \
		-- $(PWD)/godot/assets/characters/steeplejack.glb 2>&1); \
		echo "$$out" | grep -E "STEEPLEJACK|Error|Traceback"; \
		echo "$$out" | grep -q "STEEPLEJACK: wrote" || (echo "  character build failed — see Blender's output above"; exit 1)
	@$(GODOT) --path godot --headless --import >/dev/null 2>&1 || true

## ascent-sheet: the whole climb, one frame every 30 s of game time, into build/ascent-sheet/
##
## The ascent bot under a virtual display. Small frames, because every one of the ~50,000 steps
## is rendered in software; this takes tens of minutes, not seconds.
SHEET_RES ?= 640x360
ascent-sheet: godot-build godot-import
	@command -v xvfb-run >/dev/null || (echo "ascent-sheet needs xvfb-run" && exit 1)
	@rm -rf $(BUILD)/ascent-sheet && mkdir -p $(BUILD)/ascent-sheet
	@timeout 3600 xvfb-run -a -s "-screen 0 $(SHEET_RES)x24" \
		$(GODOT) --path godot --audio-driver Dummy --resolution $(SHEET_RES) --fixed-fps 60 --script res://scripts/ascent_sheet.gd \
		2>&1 | grep -vE "^(WARNING|MESA|Note:|     at:)" || true
	@echo "  $$(ls $(BUILD)/ascent-sheet | wc -l) frames in $(BUILD)/ascent-sheet/"

## godot-test: drive the real scene headlessly and assert on state
##
## Bounded, because a parse error in any .gd file makes one of these hang for ever rather than
## fail: the scene never loads, the script never reaches its quit(), and the run just sits there.
## A gate that hangs is worse than a gate that fails, because nobody reads a hang as a result.
godot-test: godot-build godot-import
	@for t in test_ladder test_character test_slip test_stance test_kit test_audio test_face test_lash_game test_stack_game test_top test_haul_game test_checkpoint test_options test_grip test_felling test_kershaws test_great_aire test_levels test_jobs test_title test_yard test_flow test_striking test_conductor test_survey test_straighten test_district test_band test_ending test_job_done test_caught test_strip_out test_went_early test_fell_audio; do \
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
	@# The mouse coming back after leaving the window needs a real window, so a virtual display.
	@command -v xvfb-run >/dev/null || (echo "godot-test needs xvfb-run for test_mouse (package xorg-x11-server-Xvfb / xvfb)" && exit 1)
	@out=$$(timeout 120 xvfb-run -a $(GODOT) --path godot --audio-driver Dummy \
		--script res://scripts/test_mouse.gd 2>&1); rc=$$?; \
		echo "$$out" | grep -E "MOUSE|FAIL|SCRIPT ERROR" || true; exit $$rc
	@# The whole game, played: cradle to cap with the real verbs. Unpaced (--fixed-fps), so fifteen
	@# minutes of game time takes under a minute; still bounded, for the same reason as above.
	@timeout 300 $(GODOT) --path godot --headless --fixed-fps 60 --script res://scripts/test_ascent.gd \
		|| (printf '\033[31mFAILED\033[0m  test_ascent (124 = hung: a parse error, or the bot stuck)\n'; exit 1)

.PHONY: godot-deps godot-build godot-import godot-test godot-editor godot-run godot-script
