# Verification

An agent cannot tell you whether its work is good. It can tell you whether a command exited zero.
So every claim this project makes about itself must be reducible to a command.

## The ladder

Cheapest and fastest first. Everything above a rung only runs if the rungs below are green.

| # | Gate | Command | Runtime | When |
|---|---|---|---|---|
| 1 | Format & lint | `make lint` | ~2 s | pre-commit, CI |
| 2 | **Enforced conventions** | `make check-conventions` | ~1 s | pre-commit, CI |
| 3 | Data validation (schemas, tuning, task graph) | `make validate` | ~2 s | pre-commit, CI |
| 4 | Doc link integrity | `make check-links` | ~1 s | CI |
| 5 | Sim unit + property tests | `make test-unit` | ~20 s | pre-commit, CI |
| 6 | Level validation (schema + beat rule + reachability) | `make test-levels` | ~30 s | CI |
| 7 | Replay regression | `make test-replay` | ~60 s | CI |
| 8 | Determinism (fell ×100, sim ×2) | `make test-determinism` | ~2 min | CI |
| 9 | Performance smoke | `make test-perf` | ~5 min | nightly |
| 10 | Screenshot diff | `make test-visual` | ~5 min | nightly |
| 11 | **Human playtest** | see the playtest plan | hours | per milestone |

`make check` runs 1–5. That's your local gate and it must be under 30 seconds, forever. If it
creeps past that, people stop running it, and then rungs 1–5 stop being real.

`make ci` runs 1–8.

## Rung 7 is the one that matters

The replay regression is the highest-leverage test in the project and it's a direct consequence of
[ADR-0003](../03-tech/adr/0003-determinism-and-testing.md).

A recorded expert run of each level, replayed headlessly, asserting the final invoice. When a
balance change alters an outcome, CI prints a diff of two invoices:

```
06-waterside: replay outcome changed
    angularError     3.1  ->  7.8
    total          £1730  -> £1480
    shiftRemaining    22  ->     19
```

That is the clearest possible summary of what a tuning change actually did to the game. A designer
can change `felling.json`, run `make test-replay`, and see the consequence across all twelve levels
in a minute — without playing any of them.

**When a change legitimately alters a replay:** re-record it, and put the invoice diff in the PR
body. The diff *is* the justification.

## Writing a verify command

Every task's `verify:` field is a single command. Prefer, in order:

1. An existing `make` target with a filter — `make test-unit FILTER=test_stack_spans`
2. A new test file that the task also owns
3. A script that asserts something about the repo — `make check-conventions`
4. A documented manual procedure — only for art, audio and playtest tasks, and then it must name
   the observable outcome and the number of observers

Never `make check` alone — that proves the repo is healthy, not that your task is done.

## What we deliberately do not test

- **Feel.** Hammer weight, camera framing, whether the tea break lands. These are playtested, not
  asserted. Attempting to unit-test them produces brittle tests and false confidence.
- **Visual fidelity**, beyond the nightly screenshot diff catching gross regressions.
- **Cross-platform float determinism.** We need determinism within a build, not across machines.
  See ADR-0003.

Being explicit about this matters: an agent that can't find a way to test "does the hammer feel
good" should write the playtest note, not invent a proxy metric.

## Pre-commit

```bash
make install-hooks      # installs .git/hooks/pre-commit
```

Runs rungs 1–3 on staged files only. Skippable with `--no-verify` for a WIP commit on your own
branch; never skippable for a PR, because CI runs the same gates.

## CI

`.github/workflows/ci.yml`. Two job groups:

- **fast** (no engine): lint, conventions, data validation, task graph, doc links. Runs on every
  push in well under a minute, and is the gate that catches most agent mistakes.
- **engine**: Godot headless — unit, property, level, replay, determinism.

Nightly adds perf and visual.

**A red CI blocks merge. There is no override.** If CI is flaky, fixing the flake is the highest
priority task in the repo, because a flaky gate is worse than no gate — it trains everyone to
ignore red.

## Coverage

`sim/` must hold **≥ 90% line coverage**, enforced at the M1 gate and thereafter. `game/` is not
coverage-gated — it's presentation, and its correctness is visual.

This asymmetry is the point of the sim/presentation split: we put all the logic somewhere it can be
tested exhaustively and cheaply, and we test the rest with our eyes.
