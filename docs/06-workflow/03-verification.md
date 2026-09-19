# Verification

An agent cannot tell you whether its work is good. It can tell you whether a command exited zero.
So every claim this project makes about itself must be reducible to a command.

## The ladder

Cheapest and fastest first. Everything above a rung only runs if the rungs below are green.

| # | Gate | Command | Runtime | When |
|---|---|---|---|---|
| 0a | **The checkers' own tests** | `make test-tools` | ~5 s | CI |
| 0b | **Every `verify:` filter runs real tests** | `make check-verify` | ~2 s | CI |
| 1 | **Enforced conventions** | `make check-conventions` | ~1 s | pre-commit, CI |
| 2 | Data validation (schemas, tuning, task graph) | `make validate` | ~2 s | pre-commit, CI |
| 3 | Doc link integrity | `make check-links` | ~1 s | CI |
| 4 | Sim build (**no engine needed**) | `make build-sim` | ~20 s | pre-commit, CI |
| 5 | Sim unit + property tests | `make test-unit` | ~10 s | pre-commit, CI |
| 6 | Level validation (schema + beat rule + reachability) | `make test-levels` | ~10 s | CI |
| 7 | Replay: the format's round trip, then the recorded Grey Box climb | `make test-replay` | ~40 s | CI (the format in `sim`, the climb in `godot`) |
| 8 | Determinism + the sim-step budget | `make test-determinism test-perf` | ~5 s | CI |
| 9 | The game, headless: every verb, and a bot that climbs to the top | `make godot-test` | ~3 min | CI (`godot` job) |
| 10 | The game, rendered: posed frames, and a whole climb as a contact sheet | `make shot`, `make ascent-sheet` | s / ~20 min | locally, and **look at them** |
| 11 | Frame-time capture on real GPUs | — | — | **does not exist yet** |
| 12 | **Human playtest** | see the playtest plan | hours | per milestone |

### Empty gates must not report success

A gate that filters the test binary by name and matches nothing still **exits zero** — a green gate
that checks nothing, which is how a suite rots into decoration. Two mechanisms stop that, and they
answer different questions.

**`test-levels`, `test-replay`, `test-determinism`** run on every CI build, long before the tests
they select exist. They count matching cases first and print a note rather than a tick:

```
  -- replay regression: no such tests yet (lands in CORE-006/TEST-002)
```

They stay green, because on a fresh clone those tests are *supposed* to be missing. The gate becomes
real the moment its tests land, with no Makefile change. If you add a gate, add it this way.

**`test-unit FILTER=...`** is the opposite case. Nobody runs it by accident: it is run by a task's
own `verify:`, to prove that task was verified. A filter matching nothing there means the
verification did not happen, so it **exits non-zero**:

```
FAILED  FILTER=test_types matched 0 of 31 test cases — nothing ran.
        A gate that runs nothing must not report success (TEST-003).
```

`make check` never passes a `FILTER`, so this cannot turn a fresh clone red.

**`make check-verify`** is the repo-wide version of the same question, because the Makefile only
ever sees one filter at a time. It cross-checks every task's `verify:` filter against the test-case
names the binary actually exposes, and fails on any task at `review` or `done` whose filter matches
nothing — a task claiming it was verified by a command that ran zero tests. Filters belonging to
unwritten modules are listed as pending, not failures. It runs in `make ci`.

**Rungs 1–8 need neither an engine nor a GPU** (except the recorded climb in 7). They cover all of
the gameplay rules and run on a GitHub-hosted runner in under two minutes. Rung 9 needs Godot, and CI's
`godot` job installs it; rung 10 renders, and is for looking at.

`make check` runs 1–5. That's your local gate and it must stay under **60 seconds**, forever. If it
creeps past that, people stop running it, and then rungs 1–5 stop being real.

`make ci` runs 1–8 — everything that does not need the engine.

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

1. An existing `make` target with a filter — `make test-unit FILTER=stack`

   **The filter matches TEST_CASE *names*, not file names.** Test cases in this repo are named
   `<Module>: <what it asserts>`, so the filter is the module: `FILTER=stack` matches
   `TEST_CASE("Stack: load shares across three anchors")`. `FILTER=test_stack` matches nothing,
   and before TEST-003 that reported SUCCESS. Now it fails, and `make check-verify` catches it
   across the whole repo.
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

`.github/workflows/ci.yml`. Three jobs:

- **fast** (no engine, no compiler): conventions, data validation, task graph, doc links. Under 30
  seconds, and it is the gate that catches most agent mistakes.
- **sim** (no engine): CMake build plus the whole doctest suite — unit, property, level, replay,
  determinism, step budget. Under two minutes on a GitHub-hosted runner.
- **godot** (the official Godot 4.7.2 build, headless): the GDExtension build, `make godot-test`
  — every verb, and the bot that climbs the Grey Box to the top — and the climb against its
  recording. About ten minutes. The recording made on a developer machine matched on GitHub's
  runner the first time, so the climb is deterministic across machines, not only on one.

**A red `sim` job is the most urgent thing in the repo**, because the sim holds every gameplay
decision.

### Rung 0 — testing the tests

`tools/test_conventions.py` tests the convention checkers themselves: 20 cases, each asserting
**both** that a rule catches its bad input **and** that it leaves a legitimate equivalent alone.
That second half is what stops a rule getting switched off the first time it fires a false positive.

A rule with no test is not a rule; it is a future false positive that someone will disable.

**A red CI blocks merge. There is no override.** If CI is flaky, fixing the flake is the highest
priority task in the repo, because a flaky gate is worse than no gate — it trains everyone to
ignore red.

## Coverage

`SteeplejackSim` must hold **≥ 90% line coverage** (gcov on an instrumented standalone build,
`make test-coverage`; 94.2% on 2026-09-19). The Godot layer is not coverage-gated — it is
presentation, checked by `make godot-test` and by looking at frames.

This asymmetry is the point of the sim/presentation split: we put all the logic somewhere it can be
tested exhaustively and cheaply, and we test the rest with our eyes.
