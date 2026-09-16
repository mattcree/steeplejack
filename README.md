# STEEPLEJACK

> *A third-person climbing and industrial-demolition game about the last of the steeplejacks.*

You are a jobbing steeplejack in the industrial North of England, late 1970s. You have a flat cap, a
ladder on the van roof, a bag of steel dogs, a hammer, and a flask of tea. The mills are closing and
their chimneys are coming down — and somebody has to go up there and do it.

**The hook:** you don't *find* a route up the chimney. You **build** it, one ladder at a time, while
hanging off it. Then you do a day's fiddly, dangerous work 90 metres above a town, and climb back
down with your gear.

---

## Read this first

| If you are… | Start here |
|---|---|
| A designer | [`docs/00-vision.md`](docs/00-vision.md) → [`docs/01-gdd/02-climbing-system.md`](docs/01-gdd/02-climbing-system.md) |
| An engineer | [`docs/03-tech/architecture.md`](docs/03-tech/architecture.md) → [`docs/03-tech/adr/`](docs/03-tech/adr/) |
| A producer / lead | [`docs/04-production/mvp.md`](docs/04-production/mvp.md) → [`docs/04-production/work-breakdown.md`](docs/04-production/work-breakdown.md) |
| An artist | [`docs/01-gdd/13-art-direction.md`](docs/01-gdd/13-art-direction.md) |
| A level designer | [`docs/02-levels/LEVEL-TEMPLATE.md`](docs/02-levels/LEVEL-TEMPLATE.md) → [`docs/02-levels/level-index.md`](docs/02-levels/level-index.md) |
| An agent picking up work | [`AGENTS.md`](AGENTS.md) → `make ready` |
| Anyone, on how work actually flows | [`docs/06-workflow/`](docs/06-workflow/00-agent-workflow.md) |

## Status

**Pre-production.** No engine code yet. The design is complete enough to build M0–M2 without further
design input, and M0 + M1 are broken down into 47 self-contained work items in
[`tasks/`](tasks/).

```bash
make ready       # 5 tasks are claimable today
make board       # 47 tasks, 83 ideal days to the M1 gate
make critical TARGET=PT-001
```

See [`docs/04-production/roadmap.md`](docs/04-production/roadmap.md) and
[`docs/06-workflow/00-agent-workflow.md`](docs/06-workflow/00-agent-workflow.md).

## The three pillars

1. **Earned altitude** — every metre is something you built and can look back down on.
2. **Craft under pressure** — precise, physical work, done where precise is hard.
3. **Controlled catastrophe** — you spend forty minutes stopping a thing from falling, so you can
   make it fall exactly where you said it would.

## Quick start

```bash
# Godot 4.4+ required. See docs/03-tech/adr/0001-engine-choice.md
godot --path . --editor            # open the project
godot --path . --headless -s tests/run_tests.gd   # run the deterministic sim tests
```

The engine choice (Godot 4) is documented in
[`ADR-0001`](docs/03-tech/adr/0001-engine-choice.md) with a fully costed alternative. **Confirm it
before M0 starts** — it is cheap to change now and expensive later. Every design document in
`docs/01-gdd/` and `docs/02-levels/` is engine-agnostic and survives the decision either way.

## Licence & likeness

This game is inspired by a real, documented trade and by techniques that are matters of public
record. It does **not** use any real person's name, likeness, voice or catchphrases.
See [`docs/05-legal/ip-and-likeness.md`](docs/05-legal/ip-and-likeness.md) — this is binding on all
content work.
