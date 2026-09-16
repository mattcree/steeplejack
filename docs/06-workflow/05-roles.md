# Roles & Handoffs

Six roles. An agent or a person can hold more than one, but **never implementer and reviewer on the
same task.**

| Role | Owns | Produces | Must not |
|---|---|---|---|
| **Design lead** | `docs/00-vision.md`, `docs/01-gdd/**` | design decisions, answers to escalations | write implementation tasks' code |
| **Task author** | `tasks/**` frontmatter + Goal/Why/Context/Interface/Acceptance | Ready tasks | leave a task at `draft` and claim it anyway |
| **Implementer** | one task's `owns:` paths | code, tests, `## Outcome` | touch files outside `owns:` |
| **Reviewer** | nothing | a pass/fail against acceptance + DoD | rewrite the implementer's work |
| **Integrator** | `main`, CI health | merges, wave planning, unblocking | let CI stay red |
| **Playtester/facilitator** | `docs/04-production/playtests/**` | scored criteria, new task IDs | help the tester during a session |

## Handoff artifacts

A handoff is a **file in the repo**, never a chat message. Chat doesn't survive a context window.

| Handoff | Artifact |
|---|---|
| Design → Task author | a spec section with an anchor |
| Task author → Implementer | the task file, at `status: ready` |
| Implementer → Reviewer | `status: review` + `## Outcome` filled in + a green `verify:` |
| Reviewer → Integrator | approval, or specific failed criteria by number |
| Implementer → Design lead (escalation) | `status: blocked` + `## Blocked` with options and a recommendation |
| Playtester → everyone | `docs/04-production/playtests/PT-NNN.md` + new task files |

## The rule about `## Outcome`

It is the single most valuable thing an agent produces after the code itself, because it carries
what the diff cannot: **what you decided and why, and what surprised you.**

The next agent in that subsystem reads your `## Outcome` and skips a day of rediscovery. An agent
that writes "Implemented as described" has thrown that away. If nothing surprised you and you made
no decisions, the task was too small to need a file — say so, and note it as a follow-up to merge
task granularity.

## Specialised agent types

Where the harness supports named agent types, map them to roles:

| Agent type | Role | Typical tasks |
|---|---|---|
| general-purpose / implementer | Implementer | `discipline: [ENG]`, `editor_required: false` |
| 3d-modeller / tech-art | Implementer | `discipline: [ART, TECH-ART]` |
| code-review | Reviewer | any task at `status: review` |
| explore/research | Task author support | gathering context for a `draft` task |

Two practical rules:

1. **A reviewer must not have implemented the task.** A fresh context is the entire value.
2. **Don't spawn an agent per file.** Spawn one per *task*, because the task is the unit that has
   acceptance criteria and an owner.

## Session boundaries

An agent's context window will end mid-subsystem. The recovery path must be a file, not a memory:

- Before a long operation, the task's `## Plan` is committed.
- On any meaningful decision, `## Outcome` gets a line — don't save it all for the end.
- A task left `in_progress` with an empty `## Outcome` and no commits for a day is **stale**;
  the integrator resets it to `ready` and unassigns it.

`make stale` lists them.
