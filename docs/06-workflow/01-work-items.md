# Work Items

One task = one file = `tasks/<ID>.md`. YAML frontmatter for machines, Markdown for humans.

**Why one file per task, rather than a board:** eight agents editing `board.yaml` in parallel is
eight merge conflicts. Eight agents each editing their own task file is zero. The board is
*computed* from the files (`make board`), never stored.

## The file

```markdown
---
id: CLIMB-001
title: Ladder stack — spans, flex bands, buckling
milestone: M1
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [VERB-005]
owns:
  - sim/stack.gd
  - tests/unit/test_stack_spans.gd
reads:
  - sim/types.gd
  - data/tuning/climbing.json
spec:
  - docs/01-gdd/02-climbing-system.md#3--ladders--the-resource
  - docs/03-tech/interfaces.md#simstackgd
verify: make test-unit FILTER=test_stack_spans
editor_required: false
risk: R1
---

## Goal
One sentence. What exists at the end that doesn't exist now.

## Why
Why this matters, pointing at a pillar or a spec decision. Two sentences.

## Context
What an agent needs to know that isn't obvious from the spec links. Prior art in the repo,
gotchas, why an earlier approach was rejected. Keep it short; link, don't copy.

## Interface
The exact signatures this task must provide, and the ones it consumes. Copied from
`docs/03-tech/interfaces.md` so the task is self-contained.

## Acceptance
Checkable criteria, numbered. Not "feels good".

## Out of scope
What a well-meaning agent will be tempted to also do. Say no here so it doesn't happen.

## Plan
(Filled in by the implementer, before building, if estimate > 1 day.)

## Blocked
(Filled in only if blocked. See the escalation format.)

## Outcome
(Filled in at handoff. What changed, decisions made, surprises, follow-ups.)
```

## Field reference

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `AREA-NNN`. Stable forever. Referenced by branches and commits. |
| `title` | yes | imperative-ish, under 70 chars |
| `milestone` | yes | `M0`…`M6` |
| `discipline` | yes | `ENG` `DES` `ART` `AUD` `TECH-ART` `PROD` |
| `estimate_days` | yes | ideal days. > 3 means it should probably be split. |
| `status` | yes | see the state table in [`00-agent-workflow.md`](00-agent-workflow.md) |
| `assignee` | yes | `null` or an agent/person identifier |
| `depends_on` | yes | list of task IDs. `[]` is fine. Validated to exist and be acyclic. |
| `owns` | yes | glob list. **The only paths this task may write.** Validated for conflicts. |
| `reads` | no | paths it needs to read. Advisory — helps an agent load the right context. |
| `spec` | yes (code/design tasks) | `path#anchor` refs. Validated that the file exists. |
| `verify` | yes | one shell command that proves the task is done |
| `editor_required` | yes | `true` if a human must drive the Godot editor. Batched separately. |
| `risk` | no | `R1`…`R10` from [`../04-production/risks.md`](../04-production/risks.md) |

## Writing good acceptance criteria

The test is: **could a reviewer who hasn't read the design tell whether this passed?**

| ❌ | ✅ |
|---|---|
| Hammering feels good | 5 strikes at 70% power with < 4° error seat a dog from 0 to ≥ 80% depth |
| Anchors are rated correctly | unit tests cover all four rating outcomes, including bent-dog and spalled-brick paths |
| The ladder bends | at a 5 m span under player load, mid-span deflection is 60–90 mm; at 3 m it is < 10 mm |
| Performance is OK | `sim.step` stays under 1.0 ms with a 28-section stack, asserted in `tests/perf` |
| Audio is distinguishable | 8/8 testers correctly identify all four tap tiers on laptop speakers in mono |

The last one isn't automatable, and that's fine — an acceptance criterion may require a human, it
just may not be vague.

## Splitting

Split a task when any of these is true:
- estimate > 3 ideal days
- it spans two disciplines that could work in parallel (e.g. sim logic + shader)
- it would own files that another ready task also wants
- half of it is `editor_required` and half isn't

The canonical split for a mechanic is:

```
VERB-00x   sim logic + unit tests        (ENG, no editor, parallelisable)
ART-00x    animation                     (ART, editor)
AUD-00x    sound                         (AUD, no editor)
UI-00x     the HUD/telegraph for it      (ENG)
```

Four agents, four owned file sets, one mechanic, no conflicts. **This is the shape to aim for.**

## Creating a task mid-flight

You will discover work. Create the task immediately, don't do it inline:

```bash
make new-task ID=CLIMB-012 TITLE="Ladder condition wear"
```

Fill it to `draft` at minimum, link it from your `## Outcome` under follow-ups, and carry on with
what you were doing. **Discovered work becomes a task, never a scope expansion.**

## Task expansion policy

Tasks are written out in full **one milestone ahead, no further.** M0 and M1 are expanded now.
M2 gets expanded at the M1 gate, from the tables in
[`../04-production/work-breakdown.md`](../04-production/work-breakdown.md).

Writing 200 detailed tasks for work six months out produces 200 stale tasks. The work breakdown
carries the shape and the estimates; task files carry the executable detail, just in time.
