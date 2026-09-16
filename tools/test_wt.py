#!/usr/bin/env python3
"""Tests for the worktree lifecycle tool.

AGENTS.md's rule is "no untested rules". `wt.py` is the machinery the whole agent
workflow runs on — it claims tasks, pushes branches and gates the merge queue — and
until this file it had no tests at all. Both defects covered here were hit in real
use during CORE-001 and LVL-000, one of them a hard deadlock on integration.

Each case asserts the tool behaves correctly AND that it does not traceback, because
a traceback is what turns a usage mistake into a bug report.

    python3 tools/test_wt.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WT = os.path.join(ROOT, "tools", "wt.py")
TOOLS = os.path.join(ROOT, "tools")

failures: list[str] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    if not cond:
        failures.append(f"{name}: {detail}")
    print(f"  {'ok  ' if cond else 'FAIL'} {name}")


def run(args: list[str], cwd: str) -> subprocess.CompletedProcess:
    # -B: do not write tools/__pycache__. A tracked or even untracked .pyc here
    # re-dirties the tree on every `make ci`, and a dirty tree makes `land` refuse
    # and `wt-status` report AT RISK — in the tool meant to be trustworthy.
    return subprocess.run([sys.executable, "-B", WT] + args, cwd=cwd,
                          capture_output=True, text=True, timeout=60,
                          env={**os.environ, "NO_COLOR": "1"})


TASK = """---
id: TEST-999
title: Fixture task
milestone: M0
discipline: [ENG]
estimate_days: 1
status: {status}
assignee: null
depends_on: []
owns:
  - nothing
verify: true
editor_required: false
---

## Goal
Fixture.
"""


def make_repo(tmp: str) -> str:
    """A minimal repo whose task file says one thing on the trunk and another on a branch."""
    r = lambda *a: subprocess.run(["git"] + list(a), cwd=tmp, capture_output=True, text=True)
    r("init", "-q", "-b", "main")
    r("config", "user.email", "t@example.invalid")
    r("config", "user.name", "Test")
    os.makedirs(os.path.join(tmp, "tasks"), exist_ok=True)
    p = os.path.join(tmp, "tasks", "TEST-999.md")

    open(p, "w").write(TASK.format(status="ready"))
    r("add", "-A"); r("commit", "-qm", "fixture")

    # the branch carries the handoff
    r("checkout", "-q", "-b", "test-999-fixture-task")
    open(p, "w").write(TASK.format(status="review"))
    r("add", "-A"); r("commit", "-qm", "handoff")

    # the trunk carries only the claim — this is the real-world split
    r("checkout", "-q", "main")
    open(p, "w").write(TASK.format(status="in_progress"))
    r("add", "-A"); r("commit", "-qm", "claim")
    return tmp


def field_on(tmp: str, branch: str) -> str:
    """Call task_field_on inside a repo whose ROOT is the fixture, not this one."""
    script = (
        "import sys; sys.path.insert(0, %r)\n"
        "import wt\n"
        "print(wt.task_field_on('TEST-999', 'status', %r))\n"
        "print(wt.task_field('TEST-999', 'status'))\n" % (TOOLS, branch)
    )
    out = subprocess.run([sys.executable, "-B", "-c", script], cwd=tmp,
                         capture_output=True, text=True, timeout=60)
    return out.stdout.strip()


def make_repo_with_origin(tmp: str) -> str:
    """A fixture with a real origin, a real worktree, and a task file that diverges.

    Heavier than make_repo, but defect 4 — land resolving the task's own file — cannot be
    exercised without an actual rebase, and that needs a remote for the backup ref and a
    worktree for land to operate on.
    """
    origin = os.path.join(tmp, "origin.git")
    repo = os.path.join(tmp, "repo")
    subprocess.run(["git", "init", "-q", "--bare", "-b", "main", origin],
                   capture_output=True)
    r = lambda *a: subprocess.run(["git"] + list(a), cwd=repo, capture_output=True, text=True)
    os.makedirs(repo)
    r("init", "-q", "-b", "main")
    r("config", "user.email", "t@example.invalid")
    r("config", "user.name", "Test")
    r("remote", "add", "origin", origin)
    os.makedirs(os.path.join(repo, "tasks"))
    path = os.path.join(repo, "tasks", "TEST-999.md")

    open(path, "w").write(TASK.format(status="ready"))
    r("add", "-A"); r("commit", "-qm", "fixture"); r("push", "-q", "origin", "main")

    # the branch: handoff plus an Outcome that must survive the resolution
    r("worktree", "add", "-q", "-b", "test-999-fixture-task",
      os.path.join(tmp, "sj-test-999"), "main")
    wt_path = os.path.join(tmp, "sj-test-999", "tasks", "TEST-999.md")
    open(wt_path, "w").write(TASK.format(status="review") + "\n## Outcome\nMUST-SURVIVE\n")
    subprocess.run(["git", "add", "-A"], cwd=os.path.join(tmp, "sj-test-999"),
                   capture_output=True)
    subprocess.run(["git", "commit", "-qm", "handoff"], cwd=os.path.join(tmp, "sj-test-999"),
                   capture_output=True)

    # the trunk: the claim, on the same line — this is what conflicts, every time
    open(path, "w").write(TASK.format(status="in_progress"))
    r("add", "-A"); r("commit", "-qm", "claim")
    return repo


def main() -> int:
    print("a missing ID is a message, not a traceback")
    for cmd, target in [("land", "land"), ("start", "wt-start"), ("drop", "wt-drop")]:
        p = run([cmd], cwd=ROOT)
        out = p.stdout + p.stderr
        check(f"`{cmd}` with no ID exits non-zero", p.returncode != 0,
              f"exit was {p.returncode}")
        check(f"`{cmd}` with no ID does not traceback", "Traceback" not in out,
              f"got: {out.strip()[:200]}")
        check(f"`{cmd}` with no ID says what is missing", "needs a task ID" in out,
              f"got: {out.strip()[:200]}")
        check(f"`{cmd}` with no ID shows a usable example", f"ID=" in out,
              f"got: {out.strip()[:200]}")

    print("status is read from the branch, not the trunk")
    with tempfile.TemporaryDirectory() as tmp:
        make_repo(tmp)
        got = field_on(tmp, "test-999-fixture-task").splitlines()
        check("branch status wins", got and got[0] == "review",
              f"expected 'review', got {got!r}")
        check("trunk status still readable", len(got) > 1 and got[1] == "in_progress",
              f"expected 'in_progress', got {got!r}")

        missing = field_on(tmp, "no-such-branch").splitlines()
        check("unknown branch falls back to the trunk",
              missing and missing[0] == "in_progress",
              f"expected 'in_progress', got {missing!r}")

    print("land gets PAST the status check when the BRANCH says review")
    with tempfile.TemporaryDirectory() as tmp:
        make_repo(tmp)
        # Branch says review, trunk says in_progress — the exact shape of the deadlock.
        # A land that reads the trunk refuses here; a land that reads the branch proceeds
        # and fails later, on the missing worktree. Asserting the ABSENCE of the status
        # refusal is what makes this a regression test rather than one more negative case:
        # every other land case here passes even with the bug reintroduced.
        p = run(["land", "TEST-999"], cwd=tmp)
        out = p.stdout + p.stderr
        check("land does not refuse on status", "not 'review'" not in out,
              f"land read the trunk, not the branch — deadlock is back. got: {out.strip()[:200]}")
        check("land proceeds past it", "no worktree at" in out,
              f"expected to reach the worktree check, got: {out.strip()[:200]}")

    print("land refuses a task whose BRANCH is not at review")
    with tempfile.TemporaryDirectory() as tmp:
        make_repo(tmp)
        # put the branch back to in_progress so land must refuse
        subprocess.run(["git", "checkout", "-q", "test-999-fixture-task"], cwd=tmp,
                       capture_output=True)
        open(os.path.join(tmp, "tasks", "TEST-999.md"), "w").write(
            TASK.format(status="in_progress"))
        subprocess.run(["git", "commit", "-qam", "back"], cwd=tmp, capture_output=True)
        subprocess.run(["git", "checkout", "-q", "main"], cwd=tmp, capture_output=True)

        p = run(["land", "TEST-999"], cwd=tmp)
        out = p.stdout + p.stderr
        check("land refuses", p.returncode != 0, f"exit was {p.returncode}")
        check("land does not traceback", "Traceback" not in out, f"got: {out.strip()[:200]}")
        check("refusal names the branch it read",
              "test-999-fixture-task" in out, f"got: {out.strip()[:300]}")

    print("land resolves the task's own file to the branch")
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo_with_origin(tmp)
        p = run(["land", "TEST-999"], cwd=repo)
        out = p.stdout + p.stderr
        check("the task file is auto-resolved, not treated as a violation",
              "taking the branch's copy" in out,
              f"got: {out.strip()[:300]}")
        check("it is not misdiagnosed as an ownership violation",
              "ownership model was violated" not in out,
              f"got: {out.strip()[:300]}")
        # land stops later, at the gate (no Makefile in the fixture) — by then the rebase
        # and the resolution have both happened, so the branch copy must have won.
        landed = open(os.path.join(tmp, "sj-test-999", "tasks", "TEST-999.md")).read()
        check("the branch's Outcome survived the resolution", "MUST-SURVIVE" in landed,
              "the trunk's copy won — --theirs is inverted, and handoffs are being discarded")
        check("the resolved file carries the branch's status",
              "status: review" in landed, f"got: {landed[:200]}")

        # Defect 3, on the same fixture: make_repo_with_origin pushes main to origin and
        # THEN commits the claim, so the local trunk is ahead of origin/main — the shape
        # every real repo is in, because agents cannot push main. A land that rebased onto
        # origin/main would not carry the claim commit, and would later die on
        # "Not possible to fast-forward".
        log = subprocess.run(["git", "log", "--oneline", "-20"],
                             cwd=os.path.join(tmp, "sj-test-999"),
                             capture_output=True, text=True).stdout
        check("the rebase used the LOCAL trunk, not origin/main", "claim" in log,
              f"branch does not contain main's claim commit — rebased onto the wrong ref. got: {log[:200]}")

    print()
    for f in failures:
        print(f"\033[31mFAIL\033[0m {f}")
    print(f"{len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
