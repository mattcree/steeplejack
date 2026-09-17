---
id: CORE-005
title: Fixed-step simulation driver with render interpolation
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: review
assignee: agent
depends_on: [CORE-004, CORE-007]
owns:
  - Source/SteeplejackSim/Public/Clock.h
  - Source/SteeplejackSim/Private/Clock.cpp
  - tests/unit/test_clock.cpp
  - Source/SteeplejackGame/SteeplejackGameMode.h
  - Source/SteeplejackGame/SteeplejackGameMode.cpp
spec:
  - docs/03-tech/interfaces.md#clockh--core-005
  - docs/03-tech/adr/0003-determinism-and-testing.md#the-split
  - docs/03-tech/architecture.md#the-frame
verify: make test-unit FILTER=clock
editor_required: false
risk: null
---

## Goal
Step the simulation at exactly 60 Hz regardless of frame rate, and interpolate presentation between steps.

## Why
Everything downstream — determinism, replay, the whole test strategy — rests on the sim advancing in fixed, reproducible increments. Getting this wrong invalidates every test in the project.

## Context
Accumulator pattern; see the pseudocode in `docs/03-tech/architecture.md` under 'The frame'. Clamp the accumulator to avoid a spiral of death after a long frame (cap at 5 steps). `Alpha()` is what presentation lerps with.

The last sentence of this section used to read "Delete `game/bootstrap.*` as part of this task and point `project.godot` at `main.tscn`" — Godot-era rot, void since ADR-0004.

## Interface
See `docs/03-tech/interfaces.md` section `Clock.h`, which is the contract:

```cpp
class SimClock {
public:
    explicit SimClock(float tick = kTick) noexcept;
    int   Advance(float realDelta) noexcept;   // steps to run, capped at kMaxCatchUpSteps
    float Alpha() const noexcept;              // [0, 1) render interpolation factor
};
```

## Acceptance
1. Feeding 1.0 s of deltas in 30 fps chunks yields exactly 60 steps; so does feeding it in 144 fps chunks.
2. `alpha()` stays in [0, 1).
3. A 2-second stall produces at most 5 steps, not 120.
4. `Sim::Step` timing is instrumented and available in dev builds.
5. ~~`game/bootstrap.*` is deleted and `main.tscn` is the main scene.~~ **Void — Godot-era.**
   ADR-0004 replaced Godot with Unreal; there is no `game/bootstrap.*`, no `main.tscn` and no
   `project.godot` in this repo. Struck rather than reinterpreted. See Outcome.

## Out of scope
Do not add the intent recorder — CORE-006 — or any gameplay.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Clock.h`, `Clock.cpp`, `tests/unit/test_clock.cpp` (12 cases). Acceptance 1–3 pass. Acceptance 4
is the UE-side `SteeplejackGameMode`, still outstanding — see below. Acceptance 5 was Godot rot and
is struck.

**The bug this found, which is the reason the task exists**

The obvious implementation — a float accumulator and `acc -= tick` in a loop — is wrong, and wrong
in a way that no reading would catch. It runs **59 steps per second at 75, 90, 100 and 144 fps**,
and 60 at 30, 60 and 120. Measured, before fixing:

```
fps= 30  sum_of_deltas=1.0000000522  steps=60
fps= 75  sum_of_deltas=1.0000000242  steps=59
fps=100  sum_of_deltas=0.9999999776  steps=59
fps=144  sum_of_deltas=1.0000000075  steps=59
```

The cause is not accumulated drift, which was my first guess and would have led to a wrong fix.
It is that `kTick` as a `float` is `0.016666668`, very slightly **larger** than 1/60 — so sixty of
them sum to more than one second and the sixtieth step never arrives. No epsilon fixes that
honestly; it just moves the boundary.

The consequence would have been a game that runs ~1.7% slow on exactly the monitors most players
own, by an amount far too small to see, and a replay recorded at 60 fps that fails to reproduce at
144. That is the highest-leverage test in the project (TEST-002) broken before it is written.

**So the accumulator is an integer**, counting exact sub-tick units (one tick = 1,000,000 units).
The frame delta is converted once, in double, and the accumulator never sees a float again. No
drift, no epsilon, and the same answer on every compiler — which is what ADR-0003 actually wants.
All four frame rates now give exactly 60, and 600 over ten seconds.

**Decisions**

- *Deltas that are negative, NaN or infinite contribute nothing.* A NaN added to a float
  accumulator makes every later comparison false and the clock never steps again — the session
  ends, silently, from one bad frame off a paused debugger. There is a test.
- *Dropped steps are counted and exposed.* `DroppedSteps()` is nonzero exactly when the frame rate
  could not keep up and simulated time was lost. That is worth surfacing in a dev HUD rather than
  leaving invisible, since it is the difference between "the game is slow" and "the game is
  skipping".
- *Beyond the cap, time is discarded, not carried.* Carrying it is the spiral of death: the next
  frame owes those steps plus its own and falls further behind every frame. A test asserts a clock
  that absorbed a 2 s stall behaves identically to a fresh one on the following frames.
- *`Alpha()` cannot reach 1.* The accumulator is always in `[0, kUnitsPerTick)` when it is read, so
  presentation is never asked to extrapolate past a state the sim has not computed.
- *A zero or negative tick falls back to 60 Hz* rather than looping forever or never stepping.

**Acceptance 5 was Godot rot**

It asked for `game/bootstrap.*` to be deleted and `main.tscn` made the main scene. None of those
exist; ADR-0004 replaced Godot with Unreal in this repo's history. The criterion is struck in the
task file rather than reinterpreted, and the `## Interface` block — which was still GDScript
(`class_name SimClock extends RefCounted`) — now points at `interfaces.md`, which has the C++
signature the implementation matches. The `spec:` anchor `#simclockgd--core-005` was dead too.

**Acceptance 4 is not done**

`SteeplejackGameMode.h/.cpp` are in this task's `owns:` and are not written. The sim half is
complete and tested; the UE half — the `Tick` that drives `Advance()`, and the `Sim::Step` timing
instrumentation — is not. Unreal is available (`make build-game UE_ROOT=...` works), so this is not
blocked, only unfinished. Flagged rather than quietly dropped: do not read the green gate as
covering it.

**Verified by running it**

A terminal harness steps this clock at 60 Hz through a 45-second shift driving the grip meter
(METER-001): 2703 steps, 45.0 s simulated, 0 dropped, final alpha 0.000. The fixed step and the
meter behave together as the GDD describes.

**Follow-ups**

- Acceptance 4: `SteeplejackGameMode` and the `Sim::Step` timing. Same task; unfinished.
- `tools/check_conventions.py` skips lines starting `constexpr` but not `static constexpr`, so a
  named constant inside a class is reported as a magic number. Annotated with `// literal:` here.
  Same checker family as the character-literal gap CORE-007 found. No task yet.
