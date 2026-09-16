# ADR-0002 — Physics & destruction

- **Status:** Accepted
- **Date:** 2026-09-16
- **Decision:** No general-purpose rigid-body destruction. Everything is authored, deterministic and
  chunked.

## Context

Two systems look like they want a physics engine and must not get one:

1. **Felling a 110 m chimney.** A naive approach simulates thousands of bricks as rigid bodies. This
   is non-deterministic, unscorable, impossible to test, and will not hold 60 fps.
2. **Topping a chimney.** The player removes hundreds of bricks. Simulating the remaining structure's
   stability with real statics is both expensive and uncontrollable.

## Decision

### Destruction: pre-fractured chunks + a hinge solver

A felling-capable chimney is authored as **N = 60–90 chunks** (a stack of rings, each ring split into
3–5 arcs). Fracture planes are baked at export time, not computed at runtime.

The fall is a **deterministic six-stage sequence**, not a simulation:

```
1. BURN      props fail in an authored order, weighted by packing quality
2. RELEASE   support polygon collapses to the rear crescent
3. HINGE     the whole shaft rotates as ONE rigid body about the crescent centroid.
             hinge axis = resultant of (gob bearing, existing lean, wind), computed once, at fire time
4. FRACTURE  bending stress σ(h) ∝ ω² · h accumulates along the shaft.
             When σ(h) > authored threshold at a joint band, the shaft splits there.
             Typically 2–4 splits. Each resulting section continues with its own angular momentum.
5. IMPACT    each section switches to a short-lived rigid body on ground contact (≤4 s of life),
             then freezes into a static rubble mesh
6. DEBRIS    particle burst + dust column, both authored, both scripted
```

Only stages 5 and 6 touch the physics engine, for at most four seconds, with at most ~90 bodies.
That is comfortably affordable.

**Determinism:** stages 1–4 are pure math with a seeded RNG. Given identical player actions, the
chimney falls identically every time. This is required for scoring, for testing, and for replays.

### Topping: a cell grid, no statics

The shaft is a grid of `courses × segments` cells. Removing a cell is a data operation. Visual
updates are:
- interactive bricks: individual instanced meshes, removed on prise
- the rest of the course: a single mesh whose top is clipped by a shader uniform, dropped by one
  course height when its interactive bricks are gone

Stability of the *remaining* structure is not simulated. It is a simple authored rule: a course is
stable if ≥ 55% of its segments remain, and the coping ring has a hand-authored interlock order.
That is enough for the gameplay and it is testable in a unit test.

### The gob: a 2D solver, not 3D physics

Base stability is a **2D centre-of-gravity vs. support-polygon** problem, solved analytically:

```gdscript
support_polygon = convex_hull(intact_cells.map(centroid) + props.map(position))
margin = signed_distance(cog_xz, support_polygon)
```

Runs in well under 0.1 ms at 32 segments. Recomputed every time a cell or prop changes, never
per-frame. Fully unit-testable with no engine.

### What the physics engine IS used for

| Use | Bodies | Notes |
|---|---|---|
| Player character | 1 | kinematic character body, not dynamic |
| Dropped tools | ≤ 3 at once | short-lived |
| Bricks down the flue | 0 | **faked**: a scripted path + the audio. Nobody can see inside the flue. |
| Bricks thrown over the side | ≤ 6 at once | short-lived, for the damage check |
| Fall impact chunks | ≤ 90, ≤ 4 s | the only heavy moment in the game |
| Ladders | 0 | **kinematic + a vertex-shader flex spring.** Never dynamic. |
| Rope / haul loads | 0 | a 2-DOF pendulum ODE, integrated at fixed step. Not a rope sim. |

## Consequences

- **Fellings are reproducible**, which makes them scorable and testable. A regression test can fell
  all three felling levels headlessly and assert the angular error.
- We lose emergent destruction. This is a feature: the player should be rewarded for *predicting*
  the fall, which requires the fall to be predictable.
- The rope pendulum and the ladder flex are both ~30 lines of code each and both carry enormous
  feel value for essentially no cost. Do them early.
