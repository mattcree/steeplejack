---
id: CAREER-001
title: "The career: money, reputation, and which letters arrive"
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-002]
owns:
  - Source/SteeplejackSim/Public/Career.h
  - Source/SteeplejackSim/Private/Career.cpp
  - tests/unit/test_career.cpp
  - godot/scenes/jobs.tscn
  - godot/scripts/jobs.gd
  - godot/scripts/test_jobs.gd
reads:
  - Source/SteeplejackSim/Public/Fell.h
  - data/tuning/economy.json
spec:
  - docs/03-tech/interfaces.md
  - docs/02-levels/level-index.md
verify: make test-unit FILTER=Career:
editor_required: false
risk: null
---

## Goal
The two things that carry between jobs — the money in the tin and whether anyone will have you
back — and a board of letters that only offers you what you have earned.

## Why
Two modes had grown up not knowing about each other, reachable only from two `make` targets, and
nothing carried from one job to the next. There was no game, only scenes.

## Context
**Everything this needed was already in `economy.json` and had never been read.** A hundred
reputation points on five star thresholds, what a job completed is worth against a job done
perfectly, what a catastrophe costs, what walking away costs, and `replayFeeFraction` for work you
have done before. The task was mostly to believe the numbers that were already there.

Two asymmetries are what make it a career rather than a counter, and both are tested:

* **Gains are first-time only.** Re-felling Waterside pays — at 40% — and makes nobody think better
  of you, so the road to five stars is new work.
* **Losses apply every time.** A chapel costs you the fourth time as much as the first.

And `paidGbp` is never negative. A game that can put you in an unrecoverable hole twelve jobs deep
is not the game this is.

`CanTake` is in the sim rather than the board because it decides what the player is allowed to do.

## Interface
[`interfaces.md`](../docs/03-tech/interfaces.md) — `Career.h`.

## Acceptance
1. Money and reputation persist between jobs, as text a person could read.
2. Reputation gates which letters appear, on the level files' own `reputationGate`.
3. A job done again pays less and moves nothing.
4. A catastrophe pays nothing and costs reputation every time.
5. Both halves of the game settle through the sim — a felling at its verdict, a climb at the top.

## Out of scope
Tools, the traction engine and the rest of the upgrade tree, which `economy.json` also authors and
which nothing reads yet.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Done, both halves.

The bug worth recording: the career persisted, so `test_felling` saw its own previous run and
**passed only the first time it was ever executed**. Both suites point at their own scratch tin now.
A test that depends on whether anybody has run it before is the worst kind of flake, because it
passes in isolation and fails only in the suite — and it would have been read as a real regression
by whoever hit it next.

Also found: `reputation.abandoned` had been sitting in `economy.json` unused since the economy was
written. It is what walking off a job costs, and it now does.
