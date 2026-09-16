---
id: CORE-011
title: Reconcile docs with what CORE-001 actually built
milestone: M0
discipline: [ENG]
estimate_days: 0.75
status: in_progress
assignee: agent
depends_on: [CORE-001, SETUP-004]
owns:
  - AGENTS.md
  - CLAUDE.md
  - README.md
  - BLOCKED.md
  - Source/SteeplejackSim/README.md
  - docs/03-tech/adr/0003-determinism-and-testing.md
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
  - docs/03-tech/architecture.md
  - docs/03-tech/interfaces.md
  - docs/03-tech/performance-budget.md
  - docs/04-production/roadmap.md
  - docs/06-workflow/00-agent-workflow.md
  - docs/06-workflow/03-verification.md
  - docs/06-workflow/06-launch.md
  - docs/04-production/work-breakdown.md
  - tools/check_conventions.py
reads:
  - Makefile
  - Steeplejack.uproject
  - CMakeLists.txt
  - Source/SteeplejackSim/SteeplejackSim.Build.cs
  - tasks/CORE-001.md
  - tasks/CORE-002.md
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#decision
verify: make check
editor_required: false
risk: R8
---

## Goal
Every statement about the engine version, the C++ standard and how `SteeplejackSim` is built
matches what CORE-001 actually built: **Unreal 5.8.2**, **C++20**, and a sim that is **linked
as library code, not registered as a loadable UE module**.

## Why
The repo says "Unreal 5.5" in about a dozen places and "plain C++17" in eleven, while the
engine installed, the `.uproject`, `CMakeLists.txt` and `SteeplejackSim.Build.cs` are all 5.8
and C++20. AGENTS.md calls the docs the spec — right now the spec is wrong, which is worse
than it being silent. The next agent to read "plain C++17" will write to a standard the build
rejects.

## Context
Both changes came out of CORE-001 and neither was speculative:

- **5.5 -> 5.8** was a deliberate call by the project lead. The Epic Linux page no longer
  leads with 5.5, nothing had ever been compiled so migration cost was zero, and 5.5.4 is a
  March 2025 build.
- **C++17 -> C++20 was forced, not chosen.** UE 5.8 removed `CppStandardVersion.Cpp17`
  entirely; UBT fails the build with "C++17 is no longer allowed". The engine's own shared PCH
  is `...Cpp20.h`. There was no configuration of 5.8 that kept the sim at C++17.

**ADR-0004 does not need reversing.** Its decision line already reads "Unreal Engine 5.5+", so
5.8 is inside the accepted decision. Append a dated note recording the concrete version and the
forced C++20 consequence; do not rewrite the decision.

**ADR-0003 needs care, not just find-and-replace.** Its determinism argument rests on the
standalone and in-engine builds compiling identical sources the same way. That argument is
intact — both are now C++20 — but the reasoning should say so explicitly rather than leaving a
stale "C++17" that reads as if nobody checked.

Three paths are deliberately **not owned here**:
- `.github/workflows/ci.yml` and `tasks/CORE-002.md` — CORE-002 owns both and the task-graph
  validator rejects the overlap. They will still say 5.5 after this closes. CORE-002 must pick
  up 5.8 when it provisions the runner.
- `tasks/SETUP-001.md` — status `done`. It records what was true when it ran. Editing a closed
  task's record to match later reality falsifies history; leave it.

Two files contain "5.5" for unrelated reasons and **must not be touched**:
`docs/02-levels/level-02-sweepers-row.md` (a 5.5 m span) and
`docs/06-workflow/02-parallel-execution.md` (5.5 ideal days).

### The sim is no longer "a UE module" and two docs still say it is
This is the one that is more than a string swap. CORE-001 set
`bRequiresImplementModule = false` and removed `SteeplejackSim` from the `.uproject` module list,
because every loadable UE module needs `IMPLEMENT_MODULE`, which needs `Modules/ModuleManager.h`,
which convention rule 1 forbids anywhere under `Source/SteeplejackSim/`. The sim is still
compiled and linked into the editor binary — `UnrealEditor.modules` lists it — it is simply never
initialised by the module manager.

Two docs still describe the old arrangement:

- `docs/03-tech/adr/0004-engine-change-to-unreal.md` — the layout block says the sim "Builds TWO
  ways: 1. as a UE module, linked into the game".
- `docs/03-tech/architecture.md` — "builds two ways — as a UE module, and as a standalone
  library".

Both are now wrong in the same way, and AGENTS.md rule 9 says when code and a doc disagree one of
them is a bug and you must say which. Here the **docs** are the bug: ADR-0004's own section
heading is "SteeplejackSim is *not* a UE module", so the body text contradicts its own title.
Reword to "linked into the game as library code" or similar — do not weaken rule 1 to match the
old prose.

### The Makefile is owned by SETUP-004, not by this task
`Makefile:105` still prints "set UE_ROOT to your Unreal 5.5 install". It is **not** in this
task's `owns:` because SETUP-004 owns the Makefile (it wires `tools/test_wt.py` into
`test-tools`), and the task-graph validator rejects two tasks owning one file without a
dependency between them — `make land` caught exactly that collision on the rebased result.

This task therefore `depends_on: [CORE-001, SETUP-004]`. Once SETUP-004 has landed, add the
Makefile to this task's `owns:` and fix the string, or hand the one-word change to whoever
lands SETUP-004. Do not leave it: it is the error message a new contributor sees when their
`UE_ROOT` is unset, so it is the single highest-traffic stale "5.5" in the repo.

### Two more stale-since-ADR-0004 files
- `docs/04-production/work-breakdown.md:26` still describes CORE-001 as "Godot project, folder
  structure, `.gitignore`, `project.godot` settings" with acceptance "project opens; Forward+
  renderer". The row for CORE-002 is stale too. The Definition of Done's first checkbox points at
  this file's acceptance column, so a stale row here quietly weakens every DoD check.
- `tools/check_conventions.py` allows the bare literal `17` with the comment "widths, and C++17".
  Harmless behaviour, stale comment. Fix the comment; do not change the allowed-literals list
  without checking what else relies on it.

## Interface
No code and no signature changes. Prose, one CI-adjacent comment, and one workflow value.

## Acceptance
1. No owned file asserts "5.5" as the engine version or "C++17" as the standard. (The
   Makefile's "Unreal 5.5" is excluded — SETUP-004 owns that file; see Context.)
2. ADR-0004 carries a dated note giving 5.8.2 as the concrete version and recording that C++20
   was forced by the engine, with its original decision line intact.
3. ADR-0003's determinism reasoning explicitly states both builds are C++20, rather than just
   having the number swapped.
4. ADR-0004 and `architecture.md` no longer describe `SteeplejackSim` as building "as a UE
   module", and say which side was the bug. ADR-0004's body text agrees with its own section
   heading.
5. `work-breakdown.md`'s CORE-001 row describes the Unreal project it actually is, not a Godot
   one.
6. `check_conventions.py`'s stale "C++17" comment is corrected.
7. `make check` passes, including link checking.
8. `BLOCKED.md` row 3 ("Install Unreal 5.5 somewhere and set `UE_ROOT`") reflects what actually
   happened, including where the engine landed.
9. The two unrelated "5.5" matches above are untouched.

## Out of scope
No engine upgrade work — CORE-001 already moved `.uproject`, `CMakeLists.txt` and the
`Build.cs`. No CI runner provisioning, that is CORE-002. Do not change any tuning value or perf
target number; only version and standard statements.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
