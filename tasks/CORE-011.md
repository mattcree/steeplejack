---
id: CORE-011
title: Update engine version pins from 5.5 to 5.8
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - AGENTS.md
  - CLAUDE.md
  - README.md
  - Makefile
  - BLOCKED.md
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
  - docs/03-tech/performance-budget.md
  - docs/04-production/roadmap.md
  - docs/06-workflow/03-verification.md
  - docs/06-workflow/06-launch.md
reads:
  - Steeplejack.uproject
  - tasks/CORE-002.md
verify: "! grep -rn '5\\.5' --include=*.md --include=Makefile docs AGENTS.md CLAUDE.md README.md Makefile BLOCKED.md | grep -v 'level-02\\|parallel-execution'"
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#decision
editor_required: false
risk: R8
---

## Goal
Every place that names a concrete engine version says **5.8**, matching the engine actually
installed and the `EngineAssociation` that CORE-001 set.

## Why
The repo currently says "5.5" in about a dozen places while the installed engine — and the
`.uproject` — are 5.8. A version pin that disagrees with reality sends the next agent to
download the wrong engine, and CORE-002 would stand up a CI runner on a version nothing else
uses.

## Context
This is documentation drift created deliberately, not accidentally. The engine version moved
during CORE-001: the Epic Linux download page no longer leads with 5.5, the project had never
been compiled so migration cost was zero, and 5.5.4 is a March 2025 build. The decision was
taken by the project lead during CORE-001.

**ADR-0004 does not need reversing.** Its decision line already reads "Unreal Engine 5.5+", so
5.8 is inside the accepted decision. What it needs is a short note recording the concrete
version and the date it was chosen — append to the ADR, do not rewrite its decision.

Two files contain "5.5" for unrelated reasons and **must not be touched**:
`docs/02-levels/level-02-sweepers-row.md` (a 5.5 m span) and
`docs/06-workflow/02-parallel-execution.md` (5.5 ideal days).

## Interface
No code. Prose and one CI workflow value.

## Acceptance
1. `grep -rn "5\.5" --include=*.md --include=Makefile .` over the owned paths returns only the
   two unrelated matches named above.
2. ADR-0004 carries a dated note recording 5.8.2 as the concrete version, with its original
   decision line intact.
3. `make check` passes, including link checking.
4. `BLOCKED.md` row 3 ("Install Unreal 5.5 somewhere and set `UE_ROOT`") is updated or closed
   to reflect what actually happened.

## Out of scope
No engine upgrade work — CORE-001 already moved `.uproject`. Do not change any tuning value or
perf target number; only the version string.

**`.github/workflows/ci.yml` and `tasks/CORE-002.md` are deliberately not owned here** — CORE-002
owns both, and the task-graph validator rejects the overlap. Those two files will still say 5.5
after this task closes. CORE-002 must pick up 5.8 when it provisions the runner; leave it a note
rather than editing its file.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
