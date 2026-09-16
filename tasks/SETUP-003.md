---
id: SETUP-003
title: Launch procedure and the blocked queue
milestone: M0
discipline: [PROD]
estimate_days: 0.5
status: done
assignee: project lead
depends_on: [SETUP-002]
owns:
  - docs/06-workflow/06-launch.md
  - BLOCKED.md
spec:
  - docs/06-workflow/02-parallel-execution.md#review-capacity-is-the-real-limit
  - docs/04-production/risks.md#r8--editor-driven-work-blocks-the-agent-team--critical-elevated-by-adr-0004
verify: make ready shows two queues; BLOCKED.md lists the standing decisions
human_required: true
editor_required: false
risk: R8
---

## Goal
Define what "go" means: a preflight, a run loop, concurrency caps, three queues, and stopping
conditions. Plus one place to look for questions waiting on a human.

## Why
The backlog was executable but the project was not launchable — nothing said how many agents to
start, on what, who reviews, where escalations go, or when to stop.

## Acceptance
1. `make ready` separates agent-claimable from needs-a-human.
2. A preflight checklist exists, distinguishing blocking items from task-gating ones.
3. Concurrency caps are stated with reasons.
4. Stopping conditions are explicit.
5. `BLOCKED.md` exists with the standing decisions the lead owes the project.

## Out of scope
No automation of the loop itself. A human decides when to spawn agents.

## Plan
n/a

## Blocked
n/a

## Outcome
**What changed:** `tasks.py` gained a `human_required` field and `make ready` now returns two
queues. `make human-queue` lists all work a human must do with its dependency state.

**The important finding:** of six ready tasks, only **two are agent-claimable**, and 10.5 ideal
days of human work is already queued at day zero. Written into the launch doc honestly rather than
presenting a fleet-ready picture. The rate limiter for the first week is the project lead, not the
agents.

**Decisions made:** concurrency capped at **4** implementers, not the 6 the parallel-execution doc
suggested. `owns:` makes parallel work safe, not free — review attention is the scarce resource,
and 4 with a free reviewer sustains better than 6 with a queue.

Stopping conditions are deliberately mechanical (5 blocked tasks, 12 days of human queue, 3
consecutive failures on the same criterion) so the decision to stop does not depend on someone's
judgement at 2am.

**Surprises:** writing the preflight surfaced that three items — the likeness denylist, a named
human for the editor queue, and a reachable lead for escalations — are hard blockers that no amount
of agent capacity substitutes for. They are now items 1, 2 and 6 in `BLOCKED.md`'s standing
decisions.

**Follow-ups:** none. The standing decisions are the lead's, by design.
