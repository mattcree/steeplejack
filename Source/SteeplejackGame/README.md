# SteeplejackGame — the presentation layer

Reads `sj::` simulation state, renders it, and sends **intents** back. Makes no gameplay decisions.
A PR that puts a gameplay decision in here will be rejected — see [`../../AGENTS.md`](../../AGENTS.md).

## Rules

- **Blueprints are glue only.** No Blueprint may tick, and no Blueprint may contain a gameplay
  decision. If it has an `if` about game rules, it belongs in `SteeplejackSim`.
- **No hand-placed level geometry.** Levels are JSON; structures are generated at runtime. A `.umap`
  holds lighting, the sky, and spawn points — nothing else.
- **One adapter layer.** `SimBridge.h` is the only place `sj::` and UE types meet. Wanting a second
  one means the boundary is wrong — escalate.
- `Content/` is binary and human-owned. Track it with Git LFS, and keep it under 25 GB.

## Layout

| Directory | Contents |
|---|---|
| `Player/` | character, camera rig, Control Rig glue, IK, input → intents |
| `Structures/` | procedural chimney / spire / lattice builders, ladders, staging |
| `Destruction/` | Chaos Geometry Collection driving, the hinge/fracture playback |
| `VFX/` | Niagara: dust, smoke, debris, weather |
| `Audio/` | MetaSounds, buses, the height mix, the tap bank |
| `UI/` | HUD, reckoning, hub screens, options |
| `Hub/` | the yard |
