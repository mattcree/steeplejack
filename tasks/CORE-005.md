---
id: CORE-005
title: Fixed-step simulation driver with render interpolation
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: done
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
`Clock.h`, `Clock.cpp`, `tests/unit/test_clock.cpp` (13 cases), and `SteeplejackGameMode.{h,cpp}`,
which drives the sim from Unreal's `Tick` and instruments it. **Acceptance 1–4 pass**; 4 was
handed off unfinished at first and finished after review. Acceptance 5 was Godot rot and is struck.
`make build-game` succeeds and the editor loads the module.

**The bug this found — corrected after review, twice**

The obvious implementation — a float accumulator and `acc -= tick` in a loop — is wrong, and wrong
in a way no reading would catch. Measured, before fixing:

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

**The magnitude, corrected.** The first version of this Outcome said the naive clock "runs 59 steps
per second" and the game would be "~1.7% slow on exactly the monitors most players own". That is
wrong by about three orders of magnitude, and a reviewer caught it by running the harness for
longer than one second — which I had not. The deficit is **one step, once**, and then never again:

```
fps=144    1 s: 59      ideal 60      shortfall 1
fps=144   10 s: 599     ideal 600     shortfall 1
fps=144   60 s: 3599    ideal 3600    shortfall 1
fps=144 3600 s: 215999  ideal 216000  shortfall 1
```

A fixed boundary offset, not a rate. One step in 216000 over an hour is 0.0005%, and nobody would
ever feel it. Affected rates measured: 75, 90, 100, 144, 165 short by one; 30, 60, 120 exact.

**The fix is still right, for the other reason.** One step in 216000 is nothing as a *rate* and
fatal for *replay*: a run recorded at 60 fps and played back at 144 is offset by a whole tick from
the first second onward, and replay regression compares state byte for byte (ADR-0003). A constant
offset is exactly as fatal there as a growing one. That is the argument that holds, and it is the
one the first draft should have made instead of reaching for a number it had not measured.

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

**Acceptance 4 — finished, after a first attempt to hand it off unfinished**

`ASteeplejackGameMode` drives `SimClock::Advance()` from Unreal's `Tick`, runs the owed steps, and
instruments them: `SCOPE_CYCLE_COUNTER` so the cost shows in `stat Game` next to everything it
competes with, plus a rate-limited log when a step exceeds the 0.5 ms budget from
`architecture.md`. The budget is measured **per step, not per frame** — a frame that ran five
catch-up steps costs five times as much and flagging that as a breach would cry wolf exactly when
the game is already struggling. `GetSimAlpha`, `GetSimTick`, `GetDroppedSteps` and
`GetLastStepMilliseconds` are `BlueprintPure`, so a dev HUD can show all of it without a Blueprint
containing a gameplay decision (rule 4).

`StepSim()` is deliberately empty and says so: intent collection is CORE-006 and the job state is
CLIMB-001 onward. What this task owns is that whatever goes there is called exactly 60 times per
second of wall time and never at any other rate.

I first submitted this task with acceptance 4 unmet and a flag saying so. A reviewer pointed at the
Definition of Done — *"A task is done when every applicable box is ticked. Not 'mostly'. Partial
work goes back to 🟡"* — and was right. It was not blocked and not infeasible; Unreal is installed
and `make build-game` is a real target. Flagging beats hiding, but neither beats finishing.

**And it immediately hit the symbol-visibility bug again.** `SteeplejackGame` would not link:
`undefined symbol: sj::SimClock::SimClock(float)`. Same cause as CORE-007, second task to cross the
boundary, exactly as **CORE-015** predicted when it was filed. `Clock.h` carries the same guarded
`SJ_API` stopgap; CORE-015 replaces both copies with one `Export.h`. Two occurrences in two
crossings is the whole argument for that task, and it is now evidence rather than a prediction.

**Verified by running it**

`make build-game UE_ROOT=/var/home/cree/UnrealEngine/UE_5.8` → `Result: Succeeded`, and the editor
boots with the module loaded.

An earlier draft cited a terminal harness "2703 steps, 45.0 s simulated". A reviewer noted it was
unreproducible — the harness is not committed, and it depends on `Meters.h`, which is on the
METER-001 branch, not this one — and internally inconsistent, since 2703 steps at 60 Hz is 45.05 s,
not 45.0. Both true. The claim is withdrawn rather than patched: an unreproducible "verified by
running it" is worth less than no claim. Committing that harness is a follow-up.

**`Config/` got swept in again, for the second time in one session**

Launching the editor to check the module loads makes Unreal write `Config/DefaultEngine.ini` and
`Config/DefaultInput.ini`, and `make wip` runs `git add -A`. The same thing happened in CORE-007,
was caught in review there, and happened again here — including another freshly generated
`SecurityToken`. Removed from the branch and from disk.

Worth stating plainly: I did not learn from the first occurrence, and a second reviewer had to
catch the identical defect. The durable fix is CORE-012's `.gitignore` rule, which exists only on
CORE-012's branch and therefore did not protect this one. **Every editor-touching task will keep
reproducing this until CORE-012 lands**, and there is no gate for it — this is rule 3, the one
CLAUDE.md says only review catches. That is an argument for landing CORE-012 ahead of anything else
that runs the editor.

**Follow-ups**

- **CORE-012 should land before any further editor-touching task**, for the reason above.
- **CORE-015** is now twice-evidenced rather than once — see above.
- A committed demo/harness tool, so "verified by running it" is reproducible by a reviewer. No task
  yet; METER-001 raises the same follow-up.
- `dropped_` widened to `int64_t` after review showed 5000 consecutive garbage deltas overflow an
  `int`. Unreachable in play; free to fix.
- `tools/check_conventions.py` skips lines starting `constexpr` but not `static constexpr`, so a
  named constant inside a class is reported as a magic number. Annotated with `// literal:` here.
  Same checker family as the character-literal gap CORE-007 found. No task yet.
