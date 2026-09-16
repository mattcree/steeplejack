# ADR-0003 — Determinism & the simulation/presentation split

- **Status:** Accepted
- **Date:** 2026-09-16
- **Decision:** A pure, engine-independent simulation core, driven at a fixed timestep, fully testable
  headlessly.

## Context

The gameplay that matters — anchor ratings, load sharing, grip/nerve, the gob solver, the felling
hinge, scoring — is all *arithmetic over small amounts of state*. If that arithmetic lives tangled
in `_process()` callbacks and node properties, it cannot be tested, cannot be balanced, and cannot
survive an engine change.

## Decision

### The split

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION  (Godot: scenes, meshes, shaders, audio, UI)  │
│  reads sim state, renders it, sends INTENT back             │
└──────────────────────────▲──────────────┬───────────────────┘
                     state │              │ intents
┌──────────────────────────┴──────────────▼───────────────────┐
│  SIMULATION  (pure GDScript, no Node, no engine calls)      │
│                                                             │
│  sim/anchor.gd      rate_anchor(joint, depth, spall) -> Rating
│  sim/stack.gd       load_share(stack, load) -> [float]      │
│  sim/meters.gd      step_grip(state, dt), step_nerve(...)   │
│  sim/gob.gd         margin(cells, props) -> float           │
│  sim/fell.gd        solve_fall(gob, lean, wind) -> FallPlan │
│  sim/topping.gd     prise(brick, release_t) -> Outcome      │
│  sim/scoring.gd     reckon(job_record) -> Invoice           │
│  sim/economy.gd                                             │
└─────────────────────────────────────────────────────────────┘
```

**Rules:**
1. Nothing in `sim/` may `extends Node`, call `get_node`, read `delta` from the engine, or touch
   `randi()`. Time is a parameter. Randomness comes from an injected seeded `Rng`.
2. `sim/` is stepped at a **fixed 60 Hz** from `_physics_process`, with an accumulator. Presentation
   interpolates between sim states for rendering.
3. All tuning constants are loaded from `data/tuning/*.json` into the sim at construction. No magic
   numbers in code, ever. This makes balance a data change, not a code change — critical for the
   playtest loop.
4. Float determinism: we only need determinism **within a platform/build**, not across platforms.
   That is achievable with fixed-step + seeded RNG and does not require fixed-point math.

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
| `sim/` unit tests | GUT, headless | every commit | must pass |
| Property tests (e.g. "margin is monotonic in cells removed") | GUT | every commit | must pass |
| Level data validation (schema + reachability) | headless script | every commit | must pass |
| Replay regression (12 recorded runs) | headless | every commit | must pass |
| Fell determinism (same input → same angular error, ×100) | headless | every commit | must pass |
| Perf smoke (frame time on a reference scene) | headless + `--write-movie` | nightly | warn |
| Screenshot diffs | xvfb + reference images | nightly | warn |
| Human playtest | people | per milestone | see playtest plan |

### The reachability validator

For every level, a headless solver confirms that a valid ladder route to the top exists given the
authored joint grid and the level's ladder allowance, at spans ≤ 6 m. **A level that fails this is a
broken level**, and it is easy to author one by accident. This test catches it in seconds instead of
in playtest.

## Consequences

- Balancing is a JSON edit + a headless test run. A designer can rebalance the whole game without an
  engineer and see the effect on 12 recorded runs in under a minute.
- The sim is portable. If ADR-0001 is reversed, ~40% of the codebase moves unchanged.
- Presentation code must never make gameplay decisions. Code review rejects any `sim/` import of a
  Godot node type.
