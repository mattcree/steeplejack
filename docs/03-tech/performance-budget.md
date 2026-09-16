# Performance Budget

## Targets

| Platform | Resolution | Target | Floor |
|---|---|---|---|
| Mid-range desktop (RX 6600 / RTX 3060 class) | 1080p | 120 fps | 90 fps |
| Steam Deck | 800p | 60 fps | 45 fps |
| Integrated graphics (Radeon 780M class) | 1080p | 60 fps | 40 fps |

Godot Forward+ on desktop, Mobile renderer as a fallback option.

## Frame budget at 60 fps (16.6 ms)

| | Budget | Notes |
|---|---|---|
| `sim.step` | **1.0 ms** | hard limit. It's arithmetic. |
| Player + animation + IK | 1.5 ms | the IK solver is the cost |
| Structure rendering | 2.0 ms | 1–3 draw calls for the chimney |
| Town backdrop | 2.5 ms | instanced, LOD'd, fog-culled |
| Weather + dust | 2.0 ms | GPU particles |
| Shadows | 2.0 ms | 2 cascades, near field only |
| Post (fog, tonemap, vignette) | 1.5 ms | |
| UI | 0.5 ms | |
| Audio | 0.5 ms | |
| Headroom | 3.1 ms | |

## Scene budgets

| | Limit |
|---|---|
| Triangles, typical frame | 900k |
| Triangles, fall moment | 1.4M (accepted spike) |
| Draw calls | ≤ 180 |
| Rigid bodies, typical | ≤ 6 |
| Rigid bodies, fall moment | ≤ 90, for ≤ 4 s |
| GPU particle systems, typical | 2 |
| GPU particle systems, fall | 5 |
| Unique materials | ≤ 24 |
| Texture memory | ≤ 512 MB |
| Shadow-casting lights | 1 (the sun) |

## The fall spike

The only moment the budget is deliberately blown. Mitigations, applied for the 6 s around impact:
1. Drop town backdrop to LOD2 (−40% tris).
2. Disable shadow cascade 2.
3. Chunks become static rubble 4 s after their first contact.
4. Cap concurrent dynamic chunks at 90; any beyond that spawn as pre-settled rubble.

A frame-time regression test asserts the fall spike stays under **33 ms** (30 fps) on the reference
machine. Dipping to 30 fps for two seconds during a controlled demolition is acceptable; stuttering
is not.

## Things that will hurt if we let them

| Risk | Mitigation | Owner |
|---|---|---|
| Per-brick meshes on a topping level | MultiMesh + shader clipping, never individual nodes | ENG |
| The joint grid as scene nodes | it's sim data; **nothing in the joint grid is a Node** | ENG |
| Fog + transparency overdraw at height | height fog in the material, not a volumetric pass | ENG |
| Hand IK every frame at distance | IK only when the player is on-screen within 30 m | ENG |
| Audio: 40 concurrent falling-brick sounds | one looping "rush" voice + a terminating thump | AUDIO |
| Town uniqueness creep | hard cap: 40 building kits, no unique textures | ART |

## Measurement

- `tests/perf/reference_scene.gd` runs headless nightly, capturing frame times on:
  Level 01 (trivial), Level 09 (two stacks, many bricks), Level 12 act 2 (the fall).
- Results are appended to `docs/03-tech/perf-history.csv` and a regression > 10% fails the nightly.
