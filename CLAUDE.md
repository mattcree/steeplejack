# Steeplejack

**Read [`AGENTS.md`](AGENTS.md) before doing anything.** It is the contract for working in this
repo and it is short.

This file exists because Claude Code auto-loads `CLAUDE.md`; `AGENTS.md` is the canonical version
and the cross-tool standard. Everything below is a summary of it — if the two ever disagree,
`AGENTS.md` wins and the divergence is a bug.

## The thirty-second version

```bash
make ready                   # what you can claim (agent-claimable vs. needs-a-human)
make wt-start ID=CORE-003    # isolated worktree, branch pushed immediately
make wip                     # commit + push. The panic button. Run it constantly.
make check                   # the gate. ~1s. Needs cmake/ninja/g++, NOT Unreal.
```

Pick a task from **AGENT-CLAIMABLE**. Open `tasks/<ID>.md`. It is self-contained — read it and the
`spec:` sections it names, and nothing else. Work only in its `owns:` paths. Fill in `## Outcome`
before you hand off.

## Never lose work

`make wip` commits and pushes in one command. Run it before anything structural and whenever you
pause. If the git guard blocks a command, that means **commit first**, not find another way — it
blocks only the commands whose damage the reflog cannot undo.

You never merge. The integrator runs `make land ID=<task>`. See
[`docs/06-workflow/07-integration.md`](docs/06-workflow/07-integration.md).

## The four things that get a PR rejected

1. An Unreal include or type in `Source/SteeplejackSim/` — it must build standalone under CMake
   with no engine present. That is what keeps this project agent-executable.
2. A numeric literal in `SteeplejackSim` that belongs in `data/tuning/*.json`.
3. Files changed outside your task's `owns:` without declaring them.
4. A real person's name, anywhere, including commit messages.

`make check-conventions` catches 1, 2 and 4. Nothing catches 3 but review.

## Never guess about

Game design, tuning targets, whether a failure needs a telegraph, whether code belongs in
`SteeplejackSim` or `SteeplejackGame`, or scope. Set `status: blocked`, fill in `## Blocked` with
the question and your recommendation, add a line to [`BLOCKED.md`](BLOCKED.md), and pick up another
task. Do not invent an answer.

Guess freely about naming, file layout inside your owned paths, test structure, and formatting.

## Where things are

| | |
|---|---|
| The contract | [`AGENTS.md`](AGENTS.md) |
| How work flows | [`docs/06-workflow/00-agent-workflow.md`](docs/06-workflow/00-agent-workflow.md) |
| Starting a run | [`docs/06-workflow/06-launch.md`](docs/06-workflow/06-launch.md) |
| Parallel work and merging | [`docs/06-workflow/07-integration.md`](docs/06-workflow/07-integration.md) |
| Every C++ signature, fixed in advance | [`docs/03-tech/interfaces.md`](docs/03-tech/interfaces.md) |
| Why the engine is what it is | [`docs/03-tech/adr/0004-engine-change-to-unreal.md`](docs/03-tech/adr/0004-engine-change-to-unreal.md) |
| What the game is | [`docs/00-vision.md`](docs/00-vision.md) |
| Questions waiting on a human | [`BLOCKED.md`](BLOCKED.md) |
