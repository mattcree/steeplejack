---
id: CORE-001
title: Unreal project, two modules, and the standalone sim build
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: in_progress
assignee: agent
depends_on: [PROD-001]
owns:
  - Steeplejack.uproject
  - CMakeLists.txt
  - Source/SteeplejackSim/SteeplejackSim.Build.cs
  - Source/SteeplejackGame/SteeplejackGame.Build.cs
  - Source/SteeplejackGame/SteeplejackGame.cpp
  - Source/Steeplejack.Target.cs
  - Source/SteeplejackEditor.Target.cs
reads:
  - docs/03-tech/architecture.md
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#the-key-structural-move-steeplejacksim-is-not-a-ue-module
  - docs/03-tech/architecture.md#repository-layout
  - docs/03-tech/performance-budget.md#targets
verify: make build-sim && make build-game
editor_required: false
risk: R8
---

## Goal
A UE 5.5 project with two modules, where `SteeplejackSim` **also** builds standalone under CMake
with no Unreal installed.

## Why
The dual build is the entire mitigation for the cost of ADR-0004. If `SteeplejackSim` ever stops
building standalone, the gameplay layer stops being agent-executable and CI stops being fast.

## Context
The scaffold already exists (`Steeplejack.uproject`, `CMakeLists.txt`, both `.Build.cs` files) but
has never been compiled — `cmake` and Unreal are not installed on the authoring machine. This task
is the first real verification of it.

`SteeplejackSim.Build.cs` depends only on `Core`, and that is for build glue, not for types.
Do not add engine dependencies to it; if the sim appears to need one, the boundary is wrong.

## Interface
No new sim interfaces. Creates the two `.Target.cs` files and the game module entry point.

## Acceptance
1. `make build-game` compiles the editor target on a machine with UE 5.5.
2. `make build-sim` compiles `SteeplejackSim` with **no Unreal installed** — verify in a container.
3. `-Wall -Wextra -Werror` is on for the standalone build and the module compiles clean.
4. The plugin list in the `.uproject` matches ADR-0004 (Chaos, GeometryCollection, ControlRig,
   FullBodyIK, MetaSound, Niagara, EnhancedInput).
5. `make check-conventions` passes against the module.
6. The editor opens and runs an empty map at the primary target's frame budget.

## Out of scope
No gameplay. No content. The fixed-step driver is CORE-005.

## Plan
- **Verify the scaffold before changing it.** Done: `make build-sim` compiles clean under
  `-Wall -Wextra -Werror -Wshadow -Wconversion` (GCC 16.2.1) with no Unreal installed, and
  `make check` is green (0 violations, 4/4 tests). Acceptance 2, 3 and 5 are met by the
  scaffold as it stood — this task's first job was proving it, and it holds.
- **Create the three missing `owns:` files**: `Source/Steeplejack.Target.cs` (game target),
  `Source/SteeplejackEditor.Target.cs` (editor target), and
  `Source/SteeplejackGame/SteeplejackGame.cpp` (the primary game module entry point).
  No gameplay in any of them — the fixed-step driver is CORE-005.
- **Reconcile `.uproject` to the engine actually being installed.** `EngineAssociation` moves
  `5.5` -> `5.8`; the plugin list is checked name-by-name against ADR-0004 (acceptance 4).
  ADR-0004's decision line reads "5.5+", so this is inside the accepted decision, not a
  reversal of it.
- **Blocked on the engine for acceptance 1 and 6.** `make build-game` and "the editor opens an
  empty map at the primary target's frame budget" cannot run until UE 5.8.2 is unpacked and
  `UE_ROOT` is set. Everything else lands first so the engine-gated half is the only thing
  waiting.
- **Raise follow-ups rather than widening scope**: the ~15 files outside `owns:` that pin "5.5"
  in prose, and this task's own `editor_required: false` tag, which contradicts acceptance 6.

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**The dual build works.** `SteeplejackSim` compiles standalone under CMake with no Unreal
installed, clean under `-Wall -Wextra -Werror -Wshadow -Wconversion` (GCC 16.2.1), and the same
sources link into the UE editor target (`Result: Succeeded`, clang 20.1.8). ADR-0004's central
mitigation had never been compiled before this task; it holds.

### What changed
- Created `Source/Steeplejack.Target.cs`, `Source/SteeplejackEditor.Target.cs` and
  `Source/SteeplejackGame/SteeplejackGame.cpp` (`IMPLEMENT_PRIMARY_GAME_MODULE` only, no gameplay).
- `Steeplejack.uproject`: `EngineAssociation` 5.5 -> 5.8; added the missing `GeometryScripting`
  plugin; removed `SteeplejackSim` from the module list.
- `SteeplejackSim.Build.cs`: `Cpp17` -> `Cpp20`, `bRequiresImplementModule = false`.
- `CMakeLists.txt`: `CMAKE_CXX_STANDARD` 17 -> 20.

### Decisions
1. **Engine is 5.8.2, not 5.5** — project lead's call during this task. ADR-0004 says "5.5+", so
   this is inside the accepted decision, not a reversal. Installed at
   `/var/home/cree/UnrealEngine/UE_5.8`; `UE_ROOT` must point there.
2. **C++20, forced not chosen.** UE 5.8 removed `CppStandardVersion.Cpp17` outright — UBT fails
   with "C++17 is no longer allowed", and the engine's own shared PCH is `...Cpp20.h`. Escalated
   and approved before committing. Both builds moved together deliberately: ADR-0003's
   identical-floats argument depends on them not diverging. Cost was nil — the sim has zero
   modules today, so this was the cheapest possible moment.
3. **The sim is library code, not a loadable UE module.** See surprises.

### Surprises
- **Rule 1 and Unreal's module system are in direct conflict.** Every loadable UE module needs
  `IMPLEMENT_MODULE`, which needs `Modules/ModuleManager.h`; rule 1 forbids Unreal headers
  anywhere under `Source/SteeplejackSim/`, and `check_conventions.py` walks the *whole* tree, so
  there is no location where such a file passes. The editor surfaced it as "The game module
  'SteeplejackSim' could not be successfully initialized after it was loaded". Resolved with
  UBT's own `bRequiresImplementModule = false` plus dropping the sim from the `.uproject` module
  list — the sim is library code `SteeplejackGame` links, which is what ADR-0004 describes. Rule 1
  stays absolute and `Build.cs` remains the single Unreal-aware file its header claims it is.
- **The `.uproject` was missing `GeometryScripting`** while `SteeplejackGame.Build.cs` already
  depended on `GeometryScriptingCore`. UBT rejects the mismatch. Pure scaffold bug.
- **Acceptance 4 is stronger than expected.** UBT validates plugin names at build time, so all
  seven ADR-0004 plugins are confirmed to exist in 5.8 — not just grep-matched.
- **`editor_required: false` on this task is wrong.** Acceptance 6 requires a human at a screen.
  Everything else here was agent-executable. The tag should be `true`, or 6 should be its own
  task; `make ready` currently advertises this as fully agent-claimable and it is not.

### Files touched outside `owns:`
- `tasks/CORE-011.md`, `tasks/CORE-012.md` — new follow-up tasks (declared here).
- `Config/` — generated by the editor on first launch, left **untracked on purpose**. See CORE-012.

### Follow-ups
- **CORE-011** — reconcile ~15 files still saying "5.5" and 11 saying "C++17". Includes the
  ADR-0004 dated note and ADR-0003's determinism reasoning.
- **CORE-012** — decide whether `Config/` is version-controlled. Urgent-ish: `make wip` runs
  `git add -A`, so it will otherwise land silently in someone else's branch.
- **Not raised, but noted:** `.github/workflows/ci.yml` and `tasks/CORE-002.md` still say 5.5;
  CORE-002 owns both and must pick up 5.8 when it provisions the runner. Rule 16 (likeness) is
  still INERT — `tools/likeness_denylist.local.txt` is empty, and `06-launch.md` calls that
  not optional before launch.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | `make build-game` compiles the editor target | PASS — `Result: Succeeded` |
| 2 | `make build-sim` with no Unreal | PASS |
| 3 | `-Wall -Wextra -Werror` clean | PASS |
| 4 | Plugin list matches ADR-0004 | PASS — UBT-validated |
| 5 | `make check-conventions` | PASS — 0 violations |
| 6 | Editor opens and runs an empty map at frame budget | **PARTIAL** — opens clean (8.05 s, zero errors, `SteeplejackGame` loaded, engine fully initialised). Frame budget NOT measured: the run used `-nullrhi`, so nothing rendered. Needs a GPU session at 1440p/TSR Quality against 60 fps target / 50 fps floor. |
