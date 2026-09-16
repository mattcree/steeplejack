# Performance Budget

> Rewritten following [ADR-0004](adr/0004-engine-change-to-unreal.md). Unreal Engine 5.5+,
> Lumen + Nanite, deferred renderer.

## Targets

| Platform | Resolution | Upscaling | Target | Floor |
|---|---|---|---|---|
| **Primary** — RX 7800 XT / RTX 4070 class | 1440p | TSR Quality | 60 fps | 50 fps |
| **Minimum** — RX 6600 / RTX 3060 class | 1080p | TSR Balanced | 60 fps | 45 fps |
| **High** — RX 7900 / RTX 4080 class | 4K | TSR Quality | 60 fps | — |
| **Steam Deck** | 800p | TSR Performance, Lumen off, Nanite on | 30 fps | **stretch goal** |

Steam Deck moved from a target to a stretch goal in ADR-0004. Revisit at M4 once the fall's cost is
known; the honest answer may be "no Deck build", and that is acceptable.

**60 fps is the target, not 120.** This is a game about deliberate, careful movement; the frame
budget is better spent on Lumen and volumetrics than on refresh rate.

## Frame budget at 60 fps (16.6 ms), primary target

| | Budget | Notes |
|---|---|---|
| `SteeplejackSim::Step` | **0.5 ms** | hard limit. It is arithmetic over a few hundred structs in plain C++. |
| Base pass (Nanite) | 3.0 ms | structures, town, props — Nanite makes this scale well |
| **Lumen GI + reflections** | 4.0 ms | the single largest cost, and the thing that makes it look photographed |
| Shadows (virtual shadow maps) | 2.0 ms | one directional light |
| **Volumetric fog** | 2.0 ms | atmospheric perspective is a gameplay system here, not a garnish |
| Character + Control Rig + cloth | 1.5 ms | one character, full-body IK, Chaos Cloth |
| Niagara (smoke, dust, weather) | 1.5 ms | |
| Post + TSR | 1.5 ms | |
| UI + audio | 0.6 ms | |
| **Headroom** | 0.0 ms | tight by design — see the scalability plan |

This budget has no slack, deliberately. Lumen and volumetrics are what the project is buying with
the engine change, and cutting them to chase headroom would defeat the decision. Slack comes from
scalability settings, not from the budget.

## Scene budgets

| | Limit |
|---|---|
| Nanite triangles, typical frame | 8M (Nanite cost is resolution-bound, not triangle-bound) |
| Non-Nanite triangles | 400k |
| Draw calls (post-Nanite) | ≤ 400 |
| Chaos rigid bodies, typical | ≤ 8 |
| Chaos rigid bodies, the fall | ≤ 120, for ≤ 5 s |
| Niagara systems, typical | 3 |
| Niagara systems, the fall | 7 |
| Unique master materials | ≤ 12 (heavy use of material instances) |
| Texture streaming pool | ≤ 4 GB primary, ≤ 2 GB minimum spec |
| `Content/` on disk | ≤ 25 GB (Git LFS; see the repo policy) |

## The two spikes

### 1. The fall (levels 6, 7, 12)

The only moment the budget is deliberately blown, for about five seconds. Mitigations applied
automatically for a 6 s window around impact:

1. Town backdrop forced to its silhouette LOD (−60% of its cost).
2. Lumen final gather quality dropped one step.
3. Chunks convert to static rubble 4 s after first contact.
4. Concurrent dynamic chunks capped at 120; overflow spawns pre-settled.
5. Dust plume gets the entire Niagara budget; other systems are culled.

**Regression test: the fall spike must stay under 33 ms (30 fps) on the primary target.** Dipping to
30 fps for two seconds during a controlled demolition is acceptable. Stuttering is not.

### 2. Topping (levels 5, 9, 12)

Hundreds of individually removable bricks. **Never individual actors.** One `InstancedStaticMesh`
per course; removal sets an instance transform to zero scale. The wall below the working face is a
single Nanite mesh whose top is clipped by a material parameter. Budget: the whole topping surface
is ≤ 3 draw calls regardless of how many bricks remain.

## Things that will hurt if we let them

| Risk | Mitigation | Owner |
|---|---|---|
| An actor per brick | ISM + material clipping, enforced in review | ENG |
| The joint grid as actors or components | it is sim data; **nothing in the joint grid touches UE** | ENG |
| Lumen cost in the fog | tune volumetric fog scattering distribution before touching Lumen quality | TECH-ART |
| Megascans at source resolution | 2K virtual textures, 4K only on the brick master | ART |
| `Content/` bloat | Git LFS, and a nightly size check that fails over 25 GB | PROD |
| Blueprint tick | Blueprints are glue only; no Blueprint may tick | ENG |
| Chaos Cloth on distant characters | cloth disabled beyond 15 m | ENG |
| Audio: 40 concurrent falling-brick voices | one looping "rush" MetaSound + a terminating thump | AUD |

## Measurement

- `tools/perf_capture.py` drives a headless UE run with `-benchmark` over three reference scenes:
  Level 01 (trivial), Level 09 (two stacks, many bricks), Level 12 act 2 (the fall).
- Results append to `docs/03-tech/perf-history.csv`; a >10% regression fails the nightly.
- **`SteeplejackSim::Step` is measured separately, in the standalone CMake build**, with no engine
  involved. That number must never exceed 0.5 ms and it is checked on every commit, not nightly.
