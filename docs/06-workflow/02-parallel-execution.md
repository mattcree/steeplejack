# Parallel Execution

> **2026-09-19 — Unreal is removed from the project ([ADR-0006](../03-tech/adr/0006-move-to-godot.md)):** the examples below name Unreal-era tasks and tools. The principle (parallel generation, serial merging; keep binary work off the critical path) is unchanged.

How to run many agents at once without them colliding, duplicating, or quietly diverging.

## The three mechanisms

### 1. File ownership

Every task declares `owns:` — the only paths it may write. Two tasks that could run at the same
time may not own overlapping paths. `make validate-tasks` enforces this:

> Ownership conflict: METER-001 and VERB-007 both own
> `Source/SteeplejackSim/Private/MetersGrip.cpp` and neither depends on the other.

Tasks connected by a dependency chain *may* overlap, because they can't run concurrently.

This is the whole trick. It converts "will these agents conflict?" from a judgement call into a
lint error.

### 2. Waves

A wave is the set of tasks whose dependencies are all satisfied. `make waves` computes them:

```
WAVE 1  (5 tasks, 8.5 ideal days, max parallel 5)
  CORE-001  Unreal project, two modules, standalone    ENG   1.5
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

The reason `Stack.cpp` and `MetersGrip.cpp` can be written simultaneously by two agents who
never speak is that [`../03-tech/interfaces.md`](../03-tech/interfaces.md) already fixes every
signature, type and contract between them.

**The rule: the interface lands before the implementations.** For any new subsystem:

```
1. One task writes the signatures into docs/03-tech/interfaces.md
   and the stubs + failing tests into `SteeplejackSim`
2. N tasks, in parallel, each own one file and make their tests pass
```

If you find yourself needing to change a shared interface mid-implementation, **stop and escalate**.
Changing an interface under three other agents is how a day gets lost.

## Worktrees

One worktree per task — real filesystem isolation on top of the logical isolation that `owns:`
provides. **Never create or remove one by hand**; the lifecycle is scripted so that work cannot be
stranded on a local disk:

```bash
make wt-start ID=CLIMB-001    # worktree + branch, pushed to origin immediately
make wip                      # commit + push, constantly
make land ID=CLIMB-001        # the merge queue — backup, rebase, verify, fast-forward
make wt-drop ID=CLIMB-001     # refuses unless merged and pushed
```

`git worktree remove` is blocked by the git guard: it takes unmerged branches and uncommitted edits
with no warning, and is the most common way agent work is lost.

**Full model, and the evidence it works:**
[`07-integration.md`](07-integration.md).

## Batching by discipline

Some work can't be parallelised by an agent at all:

| Kind | Tag | How it's handled |
|---|---|---|
| Unreal editor work (materials, Control Rig, Niagara, MetaSounds, scene assembly) | `editor_required: true` | batched into a human session; `make editor-queue` lists them |
| Foley recording | `discipline: [AUD]` | batched into a recording day |
| Playtests | `discipline: [PROD, DES]` | scheduled, see the playtest plan |

`make editor-queue` exists so that editor work accumulates visibly instead of silently blocking a
wave. If that queue is growing faster than it's being cleared, that's risk **R8** triggering — and
under [ADR-0004](../03-tech/adr/0004-engine-change-to-unreal.md) **R8 is the top risk on the
register**. Watch this number weekly, not monthly. See
[`../04-production/risks.md`](../04-production/risks.md).

### Why the sim layer is where parallelism actually lives

`SteeplejackSim` is plain C++ with no Unreal dependency, so any number of agents can build and test
it in ~20 seconds each without an engine install, a GPU, or a licence. `Content/` is binary and
serialises through one human. **Plan your waves so the agent-parallel work is always ahead of the
human-serial work**, or the editor queue becomes the schedule.

## Choosing what to run in parallel

Good parallel batches:
- **The four-way mechanic split** (sim / animation / audio / UI) — different disciplines, different
  files, one shared spec section.
- **Independent sim modules behind a fixed interface** — `Stack.cpp`, `MetersGrip.cpp`,
  `Weather.cpp`, `Haul.cpp` can all be written at once, and none of them needs Unreal installed.
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

**Parallel generation, sequential merging.** Agents generate all at once; work integrates one task
at a time through `make land`, which is lock-serialized.

- Trunk-based, fast-forward only. `main` never has a merge commit and is always green.
- Agents never merge and never push to `main`. The integrator lands.
- `land` re-runs the full gate on the **rebased** result, not on what the agent tested. The trunk
  moved while they were working; that is the whole point.
- Because of `owns:`, rebases should be trivially clean. **A conflicting rebase means an ownership
  violation happened somewhere** — find it and say so rather than just resolving it.

See [`07-integration.md`](07-integration.md) for the full model.
