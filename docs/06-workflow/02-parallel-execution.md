# Parallel Execution

How to run many agents at once without them colliding, duplicating, or quietly diverging.

## The three mechanisms

### 1. File ownership

Every task declares `owns:` — the only paths it may write. Two tasks that could run at the same
time may not own overlapping paths. `make validate-tasks` enforces this:

> Ownership conflict: CLIMB-003 and CLIMB-004 both own `game/player/states/climb.gd`
> and neither depends on the other.

Tasks connected by a dependency chain *may* overlap, because they can't run concurrently.

This is the whole trick. It converts "will these agents conflict?" from a judgement call into a
lint error.

### 2. Waves

A wave is the set of tasks whose dependencies are all satisfied. `make waves` computes them:

```
WAVE 1  (5 tasks, 8.5 ideal days, max parallel 5)
  CORE-001  Godot project skeleton                    ENG   0.5
  AUD-001   The four tap sounds                       AUD   2.0
  AUD-004   Rope, ladder, boot and breathing foley    AUD   2.0
  ENV-002   Town silhouette backdrop                  ART   1.5
  LVL-000   Grey-box MVP level                        DES   0.5
  PROD-001  Confirm ADR-0001 (engine choice)          PROD  0.5

WAVE 2  (4 tasks, 5.5 ideal days, max parallel 4)
  CORE-003  Seeded RNG                                ENG   0.5
  ...
```

Waves are a *planning* tool, not a gate. A task becomes claimable the moment its dependencies are
`done` — you don't wait for the rest of its wave.

### 3. Interface-first

The reason `sim/stack.gd` and `sim/meters_grip.gd` can be written simultaneously by two agents who
never speak is that [`../03-tech/interfaces.md`](../03-tech/interfaces.md) already fixes every
signature, type and contract between them.

**The rule: the interface lands before the implementations.** For any new subsystem:

```
1. One task writes the signatures into docs/03-tech/interfaces.md
   and the stubs + failing tests into sim/
2. N tasks, in parallel, each own one file and make their tests pass
```

If you find yourself needing to change a shared interface mid-implementation, **stop and escalate**.
Changing an interface under three other agents is how a day gets lost.

## Worktrees

Where the harness supports it, each agent works in its own git worktree. This gives real filesystem
isolation on top of the logical isolation that `owns:` provides, so a stray write can't affect
anyone else's build.

```bash
git worktree add ../sj-climb-001 -b climb-001-ladder-stack
```

One worktree per task, removed on merge. Without worktrees, one branch per task is sufficient —
`owns:` is still the real protection.

## Batching by discipline

Some work can't be parallelised by an agent at all:

| Kind | Tag | How it's handled |
|---|---|---|
| Godot editor work (animation trees, material graphs, scene composition) | `editor_required: true` | batched into a human session; `make editor-queue` lists them |
| Foley recording | `discipline: [AUD]` | batched into a recording day |
| Playtests | `discipline: [PROD, DES]` | scheduled, see the playtest plan |

`make editor-queue` exists so that editor work accumulates visibly instead of silently blocking a
wave. If that queue is growing faster than it's being cleared, that's risk **R8** triggering — see
[`../04-production/risks.md`](../04-production/risks.md).

## Choosing what to run in parallel

Good parallel batches:
- **The four-way mechanic split** (sim / animation / audio / UI) — different disciplines, different
  files, one shared spec section.
- **Independent sim modules behind a fixed interface** — `stack.gd`, `meters_grip.gd`,
  `weather.gd`, `haul.gd` can all be written at once.
- **Content authoring** — two level JSONs, two audio banks, two art kits.

Bad parallel batches:
- Anything where one task's output shape isn't decided yet.
- Two tasks in the same subsystem with no interface between them.
- More than ~6 agents on one milestone — review becomes the bottleneck and quality drops. **Cap
  concurrent in-flight tasks at 6**, and make sure at least one reviewer is free.

## Review capacity is the real limit

Six agents implementing and nobody reviewing produces a queue of six unreviewed branches and a
merge nightmare. Budget roughly **one reviewer per three implementers**, and review continuously
rather than in a batch at the end of a wave.

`make board` shows the `review` column. If it's growing, stop claiming and start reviewing.

## Merge discipline

- Trunk-based. Branch off `main`, merge back within a day or two, squash.
- Rebase onto `main` before opening a PR, never merge `main` into your branch.
- Because of `owns:`, rebases should be trivially clean. **A conflicting rebase means an ownership
  violation happened somewhere** — find it and say so rather than just resolving it.
- Never merge with a red `make check`.
