---
id: CORE-001
title: Unreal project, two modules, and the standalone sim build
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: done
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
6. The editor opens and fully initialises with no errors: `SteeplejackGame` loads, and
   `SteeplejackSim` is linked into the target without being registered as a loadable module.
   *(Amended during this task: the frame-budget half is split out to **CORE-013**, which is
   `editor_required: true`. Rationale in the Outcome.)*

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
- **`editor_required: false` on this task was wrong when found.** Acceptance 6 required a human at
  a screen while everything else was agent-executable. *Resolved during this task* by splitting
  criterion 6 into CORE-013 — see below. Kept here as the trail that led to the split, not as an
  open defect.

### Files touched outside `owns:`
- `tasks/CORE-011.md`, `tasks/CORE-012.md`, `tasks/CORE-013.md` — new follow-up tasks
  (declared here).
- `Config/` — generated by the editor on first launch, left **untracked on purpose**. See CORE-012.

### Criterion 6 was split, and why
Acceptance 6 bundled two different things: *does the editor open* (agent-checkable, headless)
and *does an empty map hold the frame budget* (needs a human watching a real GPU). The first is
verified above. The second became **CORE-013**, `editor_required: true`.

This was not tidiness. CORE-001 gates **CORE-002, CORE-003, CORE-004, CORE-010 and ENV-010** —
and `make ready` reported *nothing agent-claimable* while this task sat open. CORE-003 is
`SteeplejackSim`'s first module: pure C++, no engine, entirely agent-executable, and it was
blocked behind a GPU frame-rate reading. That is risk **R8** ("editor work blocks agents")
occurring on the first task of the project, which is precisely what ADR-0004's two-layer split
exists to prevent. Leaving the criteria fused would have made the architecture's central promise
false in its first week.

The measurement is not dropped and not weakened — CORE-013 carries the full 1440p / TSR Quality
/ 60 fps target / 50 fps floor bar, plus the working steps and the instruction to raise a task
rather than absorb a bad result.

This also resolves the `editor_required` mis-tag noted above: with criterion 6 split, CORE-001 is
genuinely `editor_required: false` and CORE-013 is genuinely `true`. `make ready` and
`make editor-queue` now describe reality.

### Criterion 6's wording was corrected after review
The first replacement wording said "an empty map with **both modules loaded**". Both halves were
wrong: decision 3 makes `SteeplejackSim` deliberately non-loadable, so both modules loading is
impossible *by design*, and the `-nullrhi` run loads no world at all — there is no `LoadMap` line
in the log, so "an empty map" was never evidenced either. It now states what was actually proven
and actually intended. The substance did not change; the sentence was claiming more than the
evidence.

### The criterion-6 amendment needs the project lead's ratification
Amending one's own acceptance criterion is a **scope** decision, and `AGENTS.md` puts scope on the
never-guess list. The honest record: I raised the split with the project lead as an explicit
choice, alongside "run the check now" and "leave it blocked", and the answer was to stop asking
and use my judgement. That is a delegation of the decision, not a review of its merits, and it is
weaker than the record behind the 5.8 and C++20 calls — both of which were put and answered
specifically.

So this is flagged, not buried: **an integrator should ratify or reverse the split before
landing**, rather than read the amended criterion and assume it was always worded that way. The
argument for it is in the section above and the measurement survives at full strength in CORE-013.
The procedure I should have followed is `## Blocked` with a recommendation.

### Follow-ups
- **CORE-013** — the empty-map frame-budget measurement split out of criterion 6.
- **Fixed during review rather than filed:** `FPSemantics = FPSemanticsMode.Precise` added to
  `SteeplejackSim.Build.cs`. ADR-0003 rule 4 requires the sim to compile with FMA fusion off so
  both builds agree on floats, and only `CMakeLists.txt` had it — the exact divergence this task
  argued against when moving both builds to C++20 together.

  **This was worse than it first looked, and the platforms differ.** On Clang/Linux
  `FPSemanticsMode.Default` already falls through to `Precise` and emits `-ffp-contract=off`
  (`ClangToolChain.cs:793`), so nothing changes today. On **MSVC**, `Default` falls through to
  `Imprecise` and emits `/fp:fast` (`VCToolChain.cs:1336`) — so the in-engine sim would have
  compiled at `/fp:fast` against CMake's `/fp:precise`. That is a live ADR-0003 rule 4 violation
  on Windows, and a considerably worse one than a missing contract flag. Setting `Precise`
  explicitly makes both platforms agree with CMake instead of relying on a per-toolchain default.

  It has no effect *yet* either way: `SteeplejackSim` has no `.cpp` files, so nothing compiles
  under it until CORE-003.
- **Fixed during review rather than filed:** `BuildSettingsVersion` and `EngineIncludeOrderVersion`
  pinned to `V7` / `Unreal5_8` in both target files. They were `Latest` because the engine was not
  installed when they were written and an unknown constant fails the build; that reason expired
  the moment 5.8.2 landed. UE 5.8 defines `Latest = V7` and `Latest = Unreal5_8`, so this is the
  same build today with the silent-change-on-upgrade removed.
- **CORE-011** — reconcile ~15 files still saying "5.5" and 11 saying "C++17". Includes the
  ADR-0004 dated note and ADR-0003's determinism reasoning.
- **CORE-012** — decide whether `Config/` is version-controlled. Urgent-ish: `make wip` runs
  `git add -A`, so it will otherwise land silently in someone else's branch.
- **For CORE-002, noted not filed — a headless editor smoke test cannot end itself.**
  `UnrealEditor-Cmd <project>` in editor mode enters the editor loop and stays there;
  `-ExecCmds="Quit"` does **not** break it. Both the implementer and the reviewer hit this
  independently during this task and both had to kill the process — it looks exactly like a hang.
  A CI smoke test must use a commandlet or `-run=`, or kill externally and judge the run by
  parsing the log for severities rather than by exit code (the exit code will be the timeout's,
  and a clean teardown ends `Received signal 15` / `Daemon is exiting without errors`, not a
  crash). This is runner work and belongs to CORE-002, not here. CORE-013 is unaffected — its
  steps are an interactive `make editor` session a human closes.
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
| 6 | Editor opens and initialises, no errors | PASS — 8.05 s, zero errors, `SteeplejackGame` loaded, `SteeplejackSim` linked but not registered (as intended), all ten plugins resolved, `Engine is initialized` |
| — | *(frame budget)* | **split to CORE-013** — see below |
