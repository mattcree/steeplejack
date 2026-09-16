# The Workflow

> How work gets done in this repo, by humans and agents, in parallel, without stepping on each
> other. This document is binding. [`../../AGENTS.md`](../../AGENTS.md) is the short version.

## The shape of it

```
                        ┌──────────────────────────────────┐
  SPEC  docs/           │  the design is the source of     │
   │                    │  truth. Code is derived from it. │
   ▼                    └──────────────────────────────────┘
  WORK ITEM  tasks/<ID>.md
   │   self-contained: goal, why, spec refs, owned files,
   │   interface contract, acceptance criteria, verify command
   ▼
  CLAIM ──► CONTEXT ──► PLAN ──► BUILD ──► VERIFY ──► HANDOFF ──► REVIEW ──► MERGE
   │                                          │
   │                                          └── fails ──► fix, re-verify
   └── blocked ──► escalate (never guess a design question)
```

Three ideas do all the work:

1. **The spec is upstream of the code.** Design lives in `docs/`. A work item never re-decides
   something the spec already decided; it points at the section and implements it. If the code and
   the spec disagree, one of them is a bug and the PR must say which.
2. **A work item is self-contained.** An agent should be able to do a task having read *only* the
   task file and the spec sections it names. If you need context the task didn't give you, that is
   a bug in the task, and you fix the task file as part of the work.
3. **Conventions are machine-enforced or they don't exist.** "Don't put Nodes in `sim/`" is a
   script, not a sentence. See [`04-enforced-conventions.md`](04-enforced-conventions.md).

---

## The loop, step by step

### 1. CLAIM

```bash
make ready            # tasks whose dependencies are all done
```

Pick one. Edit **your own task file** — set `status: in_progress` and `assignee` — and commit that
single change immediately, before you start. One file per task means claiming never conflicts with
anyone else's claim.

```bash
git commit -am "CLIMB-001: claim"
```

Don't claim more than one task at a time. Don't claim a task whose dependencies aren't `done`.

### 2. CONTEXT

Read, in this order:
1. Your task file, completely.
2. Every `spec:` reference it lists — those are *section* anchors, not whole documents. Read the
   section.
3. [`../03-tech/interfaces.md`](../03-tech/interfaces.md) for the modules you consume.

**Do not read the whole repo.** The task tells you what you need. If it genuinely doesn't, that's
a Definition-of-Ready failure: add the missing reference to the task file, note it in the PR, and
carry on.

### 3. PLAN

For tasks estimated at **more than one day**, write a short plan into the task file under
`## Plan` before writing code. Three to eight bullets. Commit it. This is the cheapest possible
place to catch a misunderstanding.

Tasks under a day: skip it.

### 4. BUILD

**You may only create or modify files matching your task's `owns:` globs.**

You may *read* anything. If the work genuinely requires changing a file you don't own:

- If it's a one-line fix and nobody else is in that file this wave → do it, and say so loudly in
  the PR body under `Out-of-scope changes`.
- Otherwise → **stop**. Set `status: blocked`, fill in `## Blocked`, and open a new task for the
  change you need. See [Escalation](#escalation).

Work on a branch named after your task: `climb-001-ladder-stack`. If you're an agent with worktree
isolation available, use it — see [`02-parallel-execution.md`](02-parallel-execution.md).

### 5. VERIFY

Every task carries one command in its `verify:` field. It must pass.

```bash
make check          # the full local gate: lint, purity, data, tasks, links, unit tests
```

Then walk the applicable sections of
[`../04-production/definition-of-done.md`](../04-production/definition-of-done.md). All of it,
honestly. A task that "works but the telegraph isn't in yet" is not done — the telegraph ships in
the same task.

### 6. HANDOFF

Fill in `## Outcome` in your task file. This is not ceremony; it is the context the *next* agent
needs and cannot get from the diff.

```markdown
## Outcome

**What changed:** `sim/stack.gd` implements spans, the four span bands and buckling.
Buckling is a timer, not an instant fail, so the player gets the 8s warning the GDD specifies.

**Decisions made:** span is measured anchor-to-anchor, not ladder-foot-to-ladder-foot. The GDD was
ambiguous; anchor-to-anchor is what the load model needs. Updated
`docs/01-gdd/02-climbing-system.md` §3 to say so.

**Surprises:** the flex multiplier in `climbing.json` had to move from 1.3 to 1.5 for the bend to
be visible at 5m. Tuning change committed; no doc change needed (the GDD gives a range).

**Follow-ups created:** CLIMB-012 (ladder condition wear), raised because the buckle threshold
needs a condition input that doesn't exist yet.
```

Then set `status: review`.

### 7. REVIEW

A different agent or person reviews. The review is against **the acceptance criteria and the DoD**,
not against taste. Specifically:

- [ ] Every acceptance criterion in the task demonstrably met
- [ ] `verify:` command passes on a clean checkout
- [ ] No files outside `owns:` changed (or they're declared and justified)
- [ ] `## Outcome` is filled in and useful
- [ ] Applicable DoD sections ticked
- [ ] Spec updated if behaviour diverged

Style nits are fine to raise but never block a merge; `gdformat` decides formatting, not people.

### 8. MERGE

Squash. Commit message starts with the task ID:

```
CLIMB-001: implement the ladder stack span model

Spans, the four span bands, and buckling as an 8s timer rather than an
instant failure. Tuning in data/tuning/climbing.json.
```

Set `status: done`. Run `make board` and check nothing is unexpectedly unblocked or still blocked.

---

## Escalation

**Guess freely about:** naming, file layout inside your owned paths, test structure, private
helpers, formatting, log messages.

**Never guess about:** game design, tuning targets, whether a failure needs a telegraph, whether
something belongs in `sim/` or `game/`, scope. Those are decided in `docs/` or by the design lead.

When blocked:

```markdown
## Blocked

**The question:** the GDD says a Poor anchor "fails when you step up hard" but doesn't define
"hard". Is the dynamic factor applied on every transition, or only above some acceleration?

**What I tried:** applied it on every transition. Result: Poor anchors fail ~100% of the time,
which makes them strictly useless rather than a tempting risk.

**Options:**
  A. threshold on transition speed (my recommendation — preserves the gamble)
  B. probabilistic, scaled by speed — rejected, violates "no hidden dice"
  C. always fail, and treat Poor as a warning tier only

**Recommendation:** A, threshold at 60% of max climb speed. Needs a tuning key.
```

Then set `status: blocked`, commit, and **move to another ready task**. Don't sit on it, and don't
invent an answer because you're stuck.

---

## Definition of Ready

A task may not be claimed unless it has all of:

- [ ] A one-sentence `## Goal` a stranger could act on
- [ ] A `## Why` that connects it to a pillar or a spec decision
- [ ] `spec:` references that **fully cover** the decisions the task needs
- [ ] `owns:` globs that are sufficient and don't overlap a concurrent task
- [ ] `## Interface` — the signatures it must provide and consume (if it's code)
- [ ] `## Acceptance` — criteria that are *checkable*, not "feels good"
- [ ] `verify:` — one command that proves it
- [ ] `estimate_days` and `depends_on`
- [ ] All `depends_on` tasks are `done`

Anything missing → `status: draft`. Getting a task to Ready is itself work, and it's the job of
whoever writes the task, not whoever picks it up.

`make validate-tasks` checks the mechanical parts of this.

---

## Task states

| State | Meaning |
|---|---|
| `draft` | not yet Ready. Do not claim. |
| `ready` | Definition of Ready met, dependencies done |
| `in_progress` | claimed, being worked |
| `blocked` | needs a decision or another task. `## Blocked` is filled in. |
| `review` | built and verified, awaiting review |
| `done` | merged |
| `cut` | deliberately dropped. Keep the file; say why in `## Outcome`. |

---

## What this workflow is not

- It is **not a ticketing system**. The task files live in the repo, next to the code, and are
  edited by the same agents doing the work. There is no external board to keep in sync.
- It is **not a substitute for design**. If a task requires a design decision, the design was
  incomplete and the fix is upstream, in `docs/`.
- It is **not optional for small tasks**. A one-line change still gets a task ID, because that ID is
  how the commit, the branch, the review and the spec link to each other.
