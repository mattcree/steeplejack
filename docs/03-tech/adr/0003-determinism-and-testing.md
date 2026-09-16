# ADR-0003 — Determinism & the simulation/presentation split

- **Status:** Accepted
- **Date:** 2026-09-16
- **Decision:** A pure, engine-independent simulation core, driven at a fixed timestep, fully testable
  headlessly.

## Context

The gameplay that matters — anchor ratings, load sharing, grip/nerve, the gob solver, the felling
hinge, scoring — is all *arithmetic over small amounts of state*. If that arithmetic lives tangled
in `Tick()` callbacks and `UPROPERTY` fields, it cannot be tested, cannot be balanced, and cannot
survive an engine change.

> **This ADR survived the engine change unaltered**, and is the reason
> [ADR-0004](0004-engine-change-to-unreal.md) was affordable. Its rule 1 is now load-bearing in a
> stronger sense: `SteeplejackSim` must build standalone under CMake with no Unreal installed, which
> is what keeps the gameplay layer testable in ~20 seconds and editable by agents.

## Decision

### The split

```
┌──────────────────────────────────────────────────────────────┐
│  SteeplejackGame  (Unreal: actors, Nanite, Lumen, Chaos, UI) │
│  reads sim state, renders it, sends INTENTs back             │
└───────────────────────────▲──────────────┬───────────────────┘
                      state │              │ intents
┌───────────────────────────┴──────────────▼───────────────────┐
│  SteeplejackSim  (plain C++17. No Unreal. Builds standalone.)│
│                                                              │
│  Anchor.h    Rate(joint, depth, spall, tuning) -> AnchorRate │
│  Load.h      LoadShare(stack, section, kN, tuning, out)      │
│  Meters.h    grip::Step(...)  nerve::Step(...)               │
│  Wobble.h    WobbleAmplitudeDeg(...)   <- the one number     │
│  Gob.h       Margin(cells, props) -> float                   │
│  Fell.h      SolveFall(gob, lean, wind) -> FallPlan          │
│  Topping.h   Prise(brick, releaseT) -> Outcome               │
│  Scoring.h   Reckon(jobRecord) -> Invoice                    │
└──────────────────────────────────────────────────────────────┘
```

**Rules:**
1. Nothing in `SteeplejackSim` may include an Unreal header, use an Unreal type, read a clock, hold
   mutable static state, or call ambient RNG. Time is a `float dt` parameter. Randomness comes from
   an injected seeded `sj::Rng&`. **It must compile under CMake with no engine installed** — that is
   the check that keeps the rest honest.
2. The sim is stepped at a **fixed 60 Hz** from the game mode's `Tick`, with an accumulator capped
   at 5 catch-up steps. Presentation interpolates between sim states for rendering.
3. All tuning constants are loaded from `data/tuning/*.json` into the sim at construction. No magic
   numbers in code, ever. This makes balance a data change, not a code change — critical for the
   playtest loop.
4. Float determinism: we only need determinism **within a platform/build**, not across platforms.
   That is achievable with fixed-step + seeded RNG and does not require fixed-point math. Compile
   the sim with `-ffp-contract=off` so the standalone and in-engine builds agree.

### Recording and replay

Every job records an **intent log**: `(tick, intent, params)`. That log plus the level seed
reproduces the entire job exactly.

This gives us, nearly for free:
- **Regression tests**: replay a recorded expert run of each level in CI, assert the final invoice.
  A balance change that breaks a level shows up as a failing test with a diff of the invoice.
- **Playtest telemetry**: ship the log, replay it locally, watch exactly what the tester did.
- **Bug reports**: a 40 KB file reproduces any bug.
- Possibly a ghost/replay feature later. Free.

**This is the single highest-leverage engineering decision in the project.** Build it in M0, before
anything else.

## Testing strategy

| Layer | Tool | Runs | Gate |
|---|---|---|---|
| Sim unit tests | doctest via CMake, **no engine** | every commit | must pass |
| Property tests (e.g. "margin is monotonic in cells removed") | doctest | every commit | must pass |
| Level data validation (schema + reachability) | doctest + Python | every commit | must pass |
| Replay regression (12 recorded runs) | doctest | every commit | must pass |
| Fell determinism (same input → same angular error, ×100) | doctest | every commit | must pass |
| `Sim::Step` budget (< 0.5 ms) | doctest | every commit | must pass |
| Presentation smoke | UE automation, self-hosted runner | every commit | must pass |
| Perf capture (frame time, 3 reference scenes) | UE `-benchmark` | nightly | warn |
| Screenshot diffs | UE, reference images | nightly | warn |
| Human playtest | people | per milestone | see playtest plan |

**Note the split.** Everything above the presentation row runs on a GitHub-hosted runner in under
two minutes with no Unreal installed. That is the practical payoff of the module boundary.

### The reachability validator

For every level, a headless solver confirms that a valid ladder route to the top exists given the
authored joint grid and the level's ladder allowance, at spans ≤ 6 m. **A level that fails this is a
broken level**, and it is easy to author one by accident. This test catches it in seconds instead of
in playtest.

## Consequences

- Balancing is a JSON edit + a headless test run. A designer can rebalance the whole game without an
  engineer and see the effect on 12 recorded runs in under a minute.
- The sim is portable. This was tested for real when ADR-0001 was reversed by ADR-0004: the design
  survived, the interfaces translated mechanically, and the reversal cost two days instead of months.
- Presentation code must never make gameplay decisions. Code review rejects any `sim/` import of a
  Godot node type.
