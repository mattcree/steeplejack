# sim/ — the pure simulation layer

**Nothing in this directory may:**
- `extends Node` or reference any Godot node type
- call `get_node`, `get_tree`, `Engine.*`, or read engine `delta`
- call `randi()`, `randf()` or `randomize()` — use the injected `Rng`
- contain a numeric literal that belongs in `data/tuning/*.json`

CI enforces all four. See [`../docs/03-tech/adr/0003-determinism-and-testing.md`](../docs/03-tech/adr/0003-determinism-and-testing.md).

Time is a parameter. Randomness is injected. Everything here is a pure function over plain data,
and everything here is unit tested.

## Planned modules (M0–M1)

| File | Task ID | Purpose |
|---|---|---|
| `rng.gd` | CORE-003 | seeded xorshift |
| `types.gd` | CORE-004 | Joint, Anchor, Section, Stack, Meters, GobCell, Prop, FallPlan |
| `joints.gd` | STRUCT-002 | joint grid generation from band definitions |
| `anchor.gd` | VERB-004 | dog-in resolution and ratings |
| `stack.gd` | CLIMB-001/002 | spans, flex, load sharing, cascade failure |
| `meters.gd` | METER-001/002 | grip and nerve |
| `wobble.gd` | METER-003 | the one number every verb reads |
| `verbs/hammer.gd` | VERB-003 | power / angle / depth |
| `verbs/lash.gd` | VERB-005 | wraps and tension |
| `verbs/haul.gd` | VERB-007 | 2-DOF pendulum |
| `weather.gd` | ENV-003 | wind curve and gusts |
| `job.gd` | MISS-001 | the job state machine |
