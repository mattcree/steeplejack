---
id: SETUP-002
title: Agent scaffolding — entry points, roles, permissions
milestone: M0
discipline: [ENG, PROD]
estimate_days: 1
status: done
assignee: project lead
depends_on: []
owns:
  - CLAUDE.md
  - .claude/**
  - tools/test_conventions.py
  - tools/coverage.py
  - tools/check_blueprints.py
  - tools/blueprint_allowlist.txt
  - tools/perf_capture.py
spec:
  - docs/06-workflow/05-roles.md
  - docs/06-workflow/04-enforced-conventions.md#adding-a-rule
verify: make test-tools && make check-blueprints
human_required: true
editor_required: false
risk: R8
---

## Goal
The four missing tools, plus the agent entry points: `CLAUDE.md`, role definitions, and a
permissions allowlist.

## Why
Four tools were referenced by the Makefile and the docs and did not exist. There was no
`CLAUDE.md`, no reviewer definition, and no permissions allowlist — so every agent would have
prompted on every `make`.

## Acceptance
1. `tools/test_conventions.py`, `coverage.py`, `check_blueprints.py`, `perf_capture.py` all exist
   and run correctly in the empty state, saying why they are inert rather than passing silently.
2. Each convention rule has a test that asserts it catches the bad case **and** does not catch a
   legitimate one.
3. `CLAUDE.md` exists and points at `AGENTS.md` as canonical.
4. `implementer` and `reviewer` agents are defined, with the reviewer unable to write code.
5. A permissions allowlist covers the routine commands and gates `push`, `rebase` and `reset`.

## Out of scope
No orchestration — that is SETUP-003.

## Plan
n/a

## Blocked
n/a

## Outcome
**What changed:** `tools/test_conventions.py` covers all six enforced sim rules across 20 cases,
half of which are false-positive checks. `coverage.py` gates `SteeplejackSim` at 90% and says
"not applicable yet" rather than passing silently. `check_blueprints.py` implements rule 18 by
inventorying Blueprints against an explicit allowlist and grepping the binary for Tick and Timer
signatures. `perf_capture.py` is nightly and requires `UE_ROOT`.

`CLAUDE.md` is a pointer to `AGENTS.md` with the four rejection reasons inline.
`.claude/agents/implementer.md` and `reviewer.md` define the two roles; the reviewer has no Write
or Edit tool, so it structurally cannot rewrite the work it is reviewing.

**Decisions made:** the reviewer's toolset omits Write/Edit deliberately. The workflow says
"do not rewrite the implementer's work"; making that a capability boundary rather than an
instruction is cheaper than trusting it.

`Read(./tools/likeness_denylist.local.txt)` is in the deny list — agents have no business reading
the real names, and the file is gitignored anyway.

**Surprises:** `check_blueprints.py` cannot meaningfully parse `.uasset` binaries. The real control
turned out to be the **allowlist**, not the grep: a new Blueprint cannot appear without someone
writing down why. The grep is a backstop. Documented as such rather than overselling it.

**Follow-ups:** none.
