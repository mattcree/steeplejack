# Working in this repo

This file is for anyone — human or agent — picking up work. Read it before your first commit.

## Orientation, in order

1. [`docs/00-vision.md`](docs/00-vision.md) — pillars and, importantly, **anti-pillars**
2. [`docs/01-gdd/01-core-loop.md`](docs/01-gdd/01-core-loop.md) — the loop
3. [`docs/01-gdd/02-climbing-system.md`](docs/01-gdd/02-climbing-system.md) — the spine
4. [`docs/03-tech/adr/`](docs/03-tech/adr/) — all three ADRs. Non-negotiable.
5. [`docs/04-production/work-breakdown.md`](docs/04-production/work-breakdown.md) — find your task ID

Then [`docs/04-production/glossary.md`](docs/04-production/glossary.md), and use those words.

## The rules that are actually enforced

1. **`sim/` is pure.** No `Node`, no `get_node`, no engine `delta`, no `randi()`. CI checks this.
2. **No magic numbers.** Every constant lives in `data/tuning/*.json`. CI greps for numeric literals
   in `sim/` outside a small allowlist.
3. **No hand-placed level geometry.** Levels are JSON. If you're tempted to open the editor to place
   a chimney, you're doing it wrong.
4. **Every failure has a telegraph, shipped in the same task.** See the fairness contract in
   [`docs/01-gdd/10-failure-and-difficulty.md`](docs/01-gdd/10-failure-and-difficulty.md).
5. **Every audio cue has a visual fallback.** See
   [`docs/01-gdd/14-accessibility.md`](docs/01-gdd/14-accessibility.md).
6. **The docs are the spec.** If your code and the doc disagree, one of them is a bug — decide which,
   fix it, and say so in the PR.

## Commits

```
CLIMB-004: seat the dog at 80% depth

Anchors now require 80% depth before they rate. Under-driven dogs
rate one tier lower. Tuning in data/tuning/climbing.json.
```

Task ID prefix, imperative mood, and say what changed in behaviour, not what files you touched.

## Before you open a PR

Run the Definition of Done checklist in
[`docs/04-production/definition-of-done.md`](docs/04-production/definition-of-done.md). All of it.

```bash
godot --path . --headless -s tests/run_tests.gd     # unit + property + replay + level validation
gdlint sim/ game/ tests/
gdformat --check sim/ game/ tests/
```

## Adding a level

1. Copy `docs/02-levels/LEVEL-TEMPLATE.md` and fill in **every** heading.
2. Write `data/levels/NN-slug.json` against `data/schemas/level.schema.json`.
3. Run the validator. It checks the Ascent Beat Rule and reachability, among other things.
4. Play it. Record an expert replay into `data/replays/`.
5. Update the content-status table in `docs/02-levels/level-index.md`.

**Target: idea → playable in under 30 minutes.** If that stops being true, stop and fix the tooling.
It's the thing that makes twelve levels affordable.

## Adding a band type

Exactly two files: a generator in `sim/joints.gd`, a visual treatment in the brick shader. Plus the
enum in `data/schemas/level.schema.json` and a row in the band table in
[`docs/03-tech/data-schemas.md`](docs/03-tech/data-schemas.md).

## Things that will get a PR rejected

- A `Node` reference in `sim/`
- A numeric literal in `sim/` that should be tuning data
- A gameplay decision made in `game/` instead of `sim/`
- A new mechanic with no telegraph
- An audio cue with no visual fallback
- A third meter (see the anti-pillars)
- Any use of a real person's name, anywhere — see
  [`docs/05-legal/ip-and-likeness.md`](docs/05-legal/ip-and-likeness.md)
- "Press E to work" — any interaction the player cannot perform better or worse

## If you disagree with the design

Good. Say so in an issue with the task ID, and argue it against the pillars and anti-pillars. The
design is written down precisely so it can be argued with. What you must not do is quietly
implement something different.
