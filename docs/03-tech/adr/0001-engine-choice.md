# ADR-0001 — Engine choice

- **Status:** Proposed — **confirm before M0 begins**
- **Date:** 2026-09-16
- **Decision:** Godot 4.4+, with a code-first authoring discipline
- **Deciders:** project lead (pending)

## Context

The project is a 3D third-person game with:
- a bespoke character controller with heavy hand/foot IK onto procedural ladder geometry
- procedurally generated 110 m structures that deform and shrink at runtime
- a deterministic destruction system
- 12 authored levels driven from data
- a substantial options/accessibility surface
- an expected build team that is **largely or wholly agent-driven**

That last point matters more than usual. An agent team is far more productive in environments where
everything is a text file, feedback is fast, and verification is headless and automatic.

## Options considered

### A. Godot 4.4+ (recommended)

**For**
- Everything needed exists: character controller base, animation tree + SkeletonIK3D, audio buses
  and effects, input remapping, settings persistence, LOD, occlusion, physics (Jolt), export to
  Linux/Windows/macOS/Steam Deck.
- `.tscn` / `.tres` are **plain text and diffable**, so agents can read and edit scenes.
- `--headless` mode runs the whole engine without a display, so simulation tests, determinism
  checks, and level-data validation all run in CI.
- GDScript is fast to write and fast to change; C# available for hot paths.
- Saves an estimated **9–14 months of engine work** vs. option B.
- Runs on the dev box (Bluefin/atomic) via Flatpak with no layering.

**Against**
- Some work is genuinely editor-driven (animation trees, material graphs, scene composition), which
  an agent cannot do directly. **Mitigation: the code-first discipline below.**
- GDScript is dynamically typed by default (mitigate: `@warning_ignore` off, static typing
  mandatory, `gdlint`/`gdformat` in CI).
- Screenshot-based verification needs a virtual display in CI (`--headless` + `--write-movie` or
  xvfb).

### B. three.js + TypeScript + Rapier + Vite

**For**
- 100% code. Every asset, scene and system is a text file an agent can author and a test can verify.
- Instant iteration; the fastest possible feedback loop.
- Trivially shareable builds (a URL), which makes playtesting much easier.
- Excellent for the grey-box prototype specifically.

**Against**
- We would have to build: animation state machine, IK solver, audio occlusion/reverb, LOD system,
  input remapping, settings UI, save system, shadow cascades, post-processing stack, and an
  accessibility layer. That is the majority of a year.
- WebGL/WebGPU perf ceiling is a real risk for a 110 m structure with 80 fracture chunks, a dust
  volume, and a town.
- No native export path without Electron/Tauri, which reintroduces most of the packaging problems.

### C. Unity / Unreal
Rejected. Unreal is overkill for stylised flat-shaded rendering and its scene files are binary
(hostile to agent teams and to code review). Unity is viable but its licensing history makes it a
poor choice for a long-lived indie project, and its scene/prefab merge story is worse than Godot's.

## Decision

**Godot 4.4+**, with this discipline:

1. **Scenes are thin.** A `.tscn` holds node structure and nothing else. All behaviour, all tuning,
   all content is in `.gd` files and `.json` data.
2. **All tuning lives in `data/tuning/*.json`**, hot-reloadable, never in exported node properties.
3. **All levels are generated at runtime from `data/levels/*.json`.** There is no hand-placed
   level geometry. A level designer edits JSON; nobody opens the editor to author a level.
4. **Static typing is mandatory** in GDScript. `gdlint` and `gdformat` run in CI.
5. **The simulation layer is engine-independent** — see
   [`0003-determinism-and-testing.md`](0003-determinism-and-testing.md). Anchor ratings, load
   sharing, gob stability, grip/nerve, scoring and the felling solver are pure functions over plain
   data, tested headlessly with no scene tree. This is the part that must be correct, and it is the
   part that would survive an engine change.
6. **Editor-only work is batched** into named tasks (`EDITOR-xxx`) that a human does, and is kept to:
   the character animation tree, the four material shaders, and the hub scene.

## Consequences

- Rule 5 is the important one: if this ADR is reversed later, the entire gameplay simulation ports
  unchanged. The cost of being wrong is bounded to the render/animation/UI layer.
- Agents can do ~85% of the work without touching the editor.
- We accept a slightly slower iteration loop than option B in exchange for not writing an engine.

## Reversal cost

| When | Cost |
|---|---|
| Before M0 | ~0 — nothing is built |
| During M1 | ~2 weeks |
| After M3 | ~4 months. Do not. |

**Confirm this ADR before M0.**
