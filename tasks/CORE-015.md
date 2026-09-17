---
id: CORE-015
title: Symbol visibility at the UE boundary — make it a convention, not a per-header guess
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [CORE-007, CORE-011, CORE-014]
owns:
  - Source/SteeplejackSim/Public/Export.h
  - Source/SteeplejackSim/Public/Rng.h
  - Source/SteeplejackSim/Public/Tuning.h
  - Source/SteeplejackSim/Public/Json.h
  - docs/03-tech/interfaces.md
  - tools/check_conventions.py
  - tools/test_conventions.py
reads:
  - Source/SteeplejackSim/SteeplejackSim.Build.cs
  - Source/SteeplejackGame/TuningHotReload.cpp
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
  - docs/03-tech/interfaces.md#the-ue-boundary
verify: make test-tools && make check
editor_required: false
risk: R8
---

## Goal
One documented, enforced rule for exporting `SteeplejackSim` symbols across the UE module
boundary, instead of the ad-hoc macro CORE-007 had to invent in one header.

## Why
UBT compiles `SteeplejackSim` as its own shared library with `-fvisibility-ms-compat`, so a class's
out-of-line member functions are **hidden** and `SteeplejackGame` cannot link against them. Nothing
catches this: `make check` is green, `make check-conventions` is green, the module compiles, and
the failure appears only at the link step of `make build-game` — which most tasks never run.

CORE-007 was the first task to call from `SteeplejackGame` into `SteeplejackSim`, so it was the
first to hit it. Every subsequent one will.

## Context
The obvious answer — UE's generated `STEEPLEJACKSIM_API` macro — **does not work here**. It expands
to `DLLEXPORT`, which is defined in an Unreal header that `SteeplejackSim` must never include
(ADR-0004). Verified: using it fails to compile with `variable has incomplete type 'class
DLLEXPORT'`.

CORE-007's stopgap, in `Tuning.h`, is the plain compiler attribute:

```cpp
#if defined(__GNUC__) || defined(__clang__)
#define SJ_API __attribute__((visibility("default")))
#else
#define SJ_API
#endif
```

That links correctly on Linux — `make build-game UE_ROOT=...` succeeds with it and fails without —
but it is defined in one header that happens to have needed it first, which is the wrong home for a
project-wide rule.

**The open question is Windows.** MSVC has no visibility attribute; it needs
`__declspec(dllexport)` when building the module and `__declspec(dllimport)` when consuming it, and
that distinction cannot come from a single macro defined inside the module's own header. It needs a
define supplied by the build. `SteeplejackSim.Build.cs` can add one via `PublicDefinitions`, and
`CMakeLists.txt` can add the matching one — but that is a decision about how the two builds are
configured, which is why this is a task rather than a patch.

`Rng.h` has the same latent problem and has not hit it only because nothing in `SteeplejackGame`
has called `sj::Rng` yet.

## Interface
Add an `Export.h` to `SteeplejackSim/Public/` defining `SJ_API`, and a short subsection under
`## The UE boundary` in `interfaces.md` stating the rule: **every `SteeplejackSim` class with
out-of-line member functions that `SteeplejackGame` may call is marked `SJ_API`.** Header-only
aggregates like those in `Types.h` do not need it and should not have it.

## Acceptance
1. `Source/SteeplejackSim/Public/Export.h` defines `SJ_API`, correct for GCC/Clang, and either
   correct for MSVC or carrying an explicit, dated note saying Windows is unsupported and why.
2. `Tuning.h`, `Rng.h` and `Json.h` (CORE-014) include it rather than defining their own;
   `Tuning.h`'s local definition is removed. Ordered after CORE-014 so that the new `Json.h` is
   covered by the rule on the day it lands rather than being the next thing to hit it.
3. `make build-game UE_ROOT=<install>` links. Removing `SJ_API` from `Tuning` makes it fail —
   demonstrate both, and record the link error in the Outcome so the next person recognises it.
4. `interfaces.md` states the rule under `## The UE boundary`.
5. `tools/check_conventions.py` flags a `SteeplejackSim` **public header** declaring a class with
   an out-of-line member function and no `SJ_API`, with a test in `tools/test_conventions.py`.
   This is the part that makes it a convention rather than a note — a rule with no test is not a
   rule.
6. `make check` stays green and `SteeplejackSim` still builds standalone under CMake with no
   Unreal present.

## Out of scope
Do not add an Unreal include, macro or type to `SteeplejackSim` to solve this — that is the
constraint, not an obstacle to route around. Do not change the sim/game split.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
