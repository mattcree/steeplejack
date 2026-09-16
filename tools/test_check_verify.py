#!/usr/bin/env python3
"""Tests for tools/check_verify.py — TEST-003.

docs/06-workflow/04-enforced-conventions.md: "A rule with no test is not a rule;
it's a future false positive that someone will disable."

There is a second reason this file has to exist. check_verify.py is a checker that
exists because a gate reported success while running nothing — so a version of it
that reported success while checking nothing would be the same bug wearing the
costume of its own fix. Every case below asserts the verdict, not just the exit code.

    python3 tools/test_check_verify.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECKER = os.path.join(ROOT, "tools", "check_verify.py")

# What the sim test binary exposes today: "<Module>: <what it asserts>".
CASES = ["Harness: doctest links and runs",
         "Rng: same seed, identical sequence",
         "Rng: forking is reproducible",
         "Types: defaults are known"]

failures: list[str] = []
ran = 0


def run(task_bodies: dict[str, str], cases: list[str] | None = CASES) -> tuple[int, str]:
    """Run the checker against a synthetic tasks/ dir and a synthetic case list."""
    with tempfile.TemporaryDirectory() as d:
        tasks = os.path.join(d, "tasks")
        os.makedirs(tasks)
        for name, body in task_bodies.items():
            with open(os.path.join(tasks, f"{name}.md"), "w", encoding="utf-8") as f:
                f.write(body)
        argv = [sys.executable, CHECKER, "--tasks-dir", tasks]
        env = dict(os.environ)
        if cases is None:
            # No case list and no binary: point BUILD at a directory that cannot exist, so
            # the checker really does fail to read the test cases rather than quietly
            # falling back to this repo's own build/.
            env["BUILD"] = os.path.join(d, "no-such-build")
        else:
            cf = os.path.join(d, "cases.txt")
            with open(cf, "w", encoding="utf-8") as f:
                f.write("\n".join(cases))
            argv += ["--cases-from", cf]
        r = subprocess.run(argv, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
        return r.returncode, r.stdout + r.stderr


def task(tid: str, status: str, verify: str) -> str:
    return (f"---\nid: {tid}\nstatus: {status}\nowns:\n  - nothing\n"
            f"verify: {verify}\n---\n\n## Goal\nSynthetic.\n")


def case(name: str, *, tasks: dict[str, str], want_exit: int,
         must_say: str | None = None, must_not_say: str | None = None,
         cases: list[str] | None = CASES):
    global ran
    ran += 1
    code, out = run(tasks, cases)
    if code != want_exit:
        failures.append(f"{name}: exit {code}, wanted {want_exit}\n{out}")
        return
    if must_say and must_say not in out:
        failures.append(f"{name}: output did not mention {must_say!r}\n{out}")
    if must_not_say and must_not_say in out:
        failures.append(f"{name}: output should not have mentioned {must_not_say!r}\n{out}")


# --- the rule it exists to enforce -------------------------------------------

case("a task at review whose filter matches nothing is an error",
     tasks={"A-001": task("A-001", "review", "make test-unit FILTER=nonesuch")},
     want_exit=1, must_say="never verified")

case("...and at done too",
     tasks={"A-002": task("A-002", "done", "make test-unit FILTER=nonesuch")},
     want_exit=1, must_say="never verified")

# The other half of every rule: it leaves the legitimate equivalent alone.
case("a task at review whose filter matches real cases passes",
     tasks={"A-003": task("A-003", "review", "make test-unit FILTER=rng")},
     want_exit=0, must_not_say="never verified")

case("matching is case-insensitive, as doctest's own --test-case is",
     tasks={"A-004": task("A-004", "review", "make test-unit FILTER=RNG")},
     want_exit=0, must_not_say="never verified")

# --- the distinction the task asks us to keep --------------------------------

case("a not-yet-started task may point at tests that do not exist",
     tasks={"B-001": task("B-001", "ready", "make test-unit FILTER=wobble")},
     want_exit=0, must_say="pending")

case("an in_progress task may too — the tests are being written right now",
     tasks={"B-002": task("B-002", "in_progress", "make test-unit FILTER=wobble")},
     want_exit=0, must_say="pending")

# --- file-shaped filters ------------------------------------------------------

case("a filter naming a file is flagged, because it can never match a case name",
     tasks={"C-001": task("C-001", "ready", "make test-unit FILTER=test_types")},
     want_exit=0, must_say="names a file")

case("...but a module-shaped filter of the same module is not",
     tasks={"C-002": task("C-002", "ready", "make test-unit FILTER=types")},
     want_exit=0, must_not_say="names a file")

case("a file-shaped filter on a REVIEWED task is still a hard error, not a warning",
     tasks={"C-003": task("C-003", "review", "make test-unit FILTER=test_types")},
     want_exit=1, must_say="never verified")

# --- parsing ------------------------------------------------------------------

case("trailing prose after the filter is not part of the filter",
     tasks={"D-001": task("D-001", "review",
                          "make test-unit FILTER=rng, plus a video of the tea break")},
     want_exit=0, must_not_say="never verified")

case("test-automation filters are not checked against the doctest binary",
     tasks={"D-002": task("D-002", "done", "make test-automation FILTER=Smokecamera")},
     want_exit=0, must_say="not the doctest binary")

case("a verify: with no filter at all is ignored",
     tasks={"D-003": task("D-003", "done", "make check-conventions")},
     want_exit=0, must_not_say="D-003")

case("a task file with no frontmatter does not crash the checker",
     tasks={"D-004": "# Just a heading, no frontmatter\n"},
     want_exit=0)

# --- refusing to report green without looking ---------------------------------

case("an unreadable test binary is an error, not an empty case list",
     tasks={"E-001": task("E-001", "done", "make test-unit FILTER=rng")},
     want_exit=1, must_say="Refusing to report green", cases=None)


def main() -> int:
    for f in failures:
        print(f"\033[31mFAIL\033[0m {f}")
    # Counted as the cases run, never hardcoded. A test harness that reports a total it did not
    # measure is the same decoration failure this whole task exists to remove, one level up.
    if ran == 0:
        print("\033[31mFAIL\033[0m no cases ran at all")
        return 1
    print(f"\n{ran - len(failures)}/{ran} check_verify cases passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
