# Definition of Done

A task is done when **every** applicable box is ticked. Not "mostly". Partial work goes back to 🟡.

## Every task

- [ ] Meets the acceptance criterion written in [`work-breakdown.md`](work-breakdown.md)
- [ ] The standalone sim build compiles clean at `-Wall -Wextra -Werror -Wconversion`
- [ ] CI is green (unit + property + replay + level validation)
- [ ] No new warnings
- [ ] Commit message starts with the task ID (`CLIMB-004: seat the dog`)
- [ ] The relevant doc in `docs/` is updated if behaviour differs from what it says
      — **the docs are the spec; a divergence is a bug in one of them, and you must say which**

## Any task touching `SteeplejackSim`

- [ ] **`make build-sim` succeeds with no Unreal installed** — no engine headers, no engine types
- [ ] No ambient RNG, no clocks, no mutable statics, no stdout
- [ ] All constants come from `data/tuning/*.json` — **zero magic numbers**
- [ ] Unit tests cover every branch, including the failure outcomes
- [ ] Deterministic: same seed + same intents → identical state, verified twice in the test
- [ ] `Sim::Step` stays under 0.5 ms combined with the rest of the sim

## Any gameplay mechanic

- [ ] **Fairness contract**: the player can say in one sentence why it went wrong
- [ ] Every failure has a telegraph, and the telegraph shipped in the same task
- [ ] Every audio cue has a visual fallback (and vice versa where it matters)
- [ ] Tuning is exposed in JSON and hot-reloads
- [ ] Works at 30 fps and at 144 fps identically (fixed step verified)
- [ ] Works with the accessibility assists that apply to it, and produces the same outcomes

## Any player-facing action

- [ ] Input → visible response ≤ 50 ms
- [ ] Remappable, and has a hold→toggle option if it uses a hold
- [ ] Has an animation with anticipation and follow-through (not a snap)
- [ ] Has a sound with a real transient
- [ ] Readable at 720p and at 200% UI scale
- [ ] Does not rely on colour alone to convey anything

## Any level

- [ ] Passes schema validation
- [ ] Passes the reachability solver
- [ ] Obeys the **Ascent Beat Rule** (no `plain` band over 20 m)
- [ ] Has an expert replay recorded in `data/replays/`, green in CI
- [ ] Completable within `shiftMinutes` by a competent player, verified by the replay
- [ ] Its doc in `docs/02-levels/` matches what is actually built
- [ ] Every beat listed in that doc is present and identifiable in play
- [ ] Every failure mode listed in that doc is reachable and telegraphed

## Any art task

- [ ] Within the triangle and draw-call budget for its category
- [ ] Palette members only (see [`../01-gdd/13-art-direction.md`](../01-gdd/13-art-direction.md))
- [ ] Megascans or an instance of an existing master material — **no bespoke material authoring**
- [ ] Binary assets committed through Git LFS
- [ ] Readable in silhouette
- [ ] No unique textures on background assets
- [ ] Nanite enabled on static geometry; no hand-authored LOD chains
- [ ] LODs authored where the budget requires them

## Any audio task

- [ ] Distinguishable on laptop speakers, in mono, at low volume — **tested, not assumed**
- [ ] Correctly routed to a bus; obeys the height mix
- [ ] Mechanical-signal sounds duck everything else by 6 dB
- [ ] Has a visual fallback registered in the A11Y cue system

## Before a milestone gate

- [ ] All milestone tasks done by the above
- [ ] Playtest run and written up, with the gate criteria scored numerically
- [ ] Perf measured on all three platform targets and recorded in `perf-history.csv`
- [ ] Accessibility spot-check: complete the newest level muted, and again with all motion off
- [ ] `docs/02-levels/level-index.md` content-status table updated
