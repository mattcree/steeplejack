#!/usr/bin/env python3
"""Rule: a task's `verify:` command must actually run something — TEST-003.

`make test-unit FILTER=rng` reported SUCCESS against 0 of 23 test cases during
CORE-003, because doctest's `--test-case` matches test-case *names* and nothing
was called "rng" yet. The task's stated verification passed without executing a
single assertion. That is how a suite rots into decoration.

The Makefile now refuses that at the point of use: a FILTER matching nothing
exits non-zero instead of printing SUCCESS. This checker is the other half — it
answers the question the Makefile cannot, because the Makefile only ever sees one
filter at a time:

    across every task in the repo, is any *completed* task's verify: filter
    pointing at test cases that do not exist?

A filter matching nothing is fine while the module it names is still unwritten —
that is most of this repo today, and `make check` must stay green on a fresh
clone. It is not fine once the task claiming it reaches `review` or `done`,
because at that point the task is asserting it was verified.

    python3 tools/check_verify.py              # audit the repo
    python3 tools/check_verify.py --quiet      # errors only

Options exist for the tests (tools/test_check_verify.py): --tasks-dir and
--cases-from feed synthetic input so the checker can be tested without building
the sim.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS = os.path.join(ROOT, "tasks")
SIM_TESTS = os.path.join(ROOT, os.environ.get("BUILD", "build"), "sim_tests")

# A task at one of these statuses is claiming it has been verified. Anything earlier
# is still allowed to point at tests that do not exist yet.
VERIFIED_STATUSES = ("review", "done")

# Test cases in this repo are named "<Module>: <what it asserts>" (see tests/unit/), so a
# useful filter names the module. A filter shaped like a *file* — `test_types`, `test_level`,
# `test_recovery` — can never match one, whatever module lands later. That cannot be proven
# until the tests exist, so it is a warning, not an error: it tells the agent claiming the
# task to fix the filter before they discover it the hard way at handoff.
FILE_SHAPED = re.compile(r"^test[_-]|\.cpp$", re.I)

# `verify:` is prose as often as it is a command, so match the invocation rather
# than assuming the whole line is shell. Only `test-unit` runs the doctest binary;
# `test-automation` runs inside Unreal and cannot be checked from here.
UNIT_FILTER = re.compile(r"make\s+test-unit\b[^\n]*?\bFILTER=(\S+)")
OTHER_FILTER = re.compile(r"make\s+(test-automation|test-levels|test-replay|test-determinism)"
                          r"\b[^\n]*?\bFILTER=(\S+)")

C = {"red": "\033[31m", "yel": "\033[33m", "grn": "\033[32m",
     "dim": "\033[2m", "bold": "\033[1m", "off": "\033[0m"}

errors: list[str] = []


def strip_prose(value: str) -> str:
    """`FILTER=test_recovery, plus a video of the tea break` -> `test_recovery`.

    Several verify: lines append an English clause after the command. Trailing
    punctuation is never part of a doctest filter, so dropping it reads the line
    the way a human would rather than failing on the comma.
    """
    return value.rstrip(",.;:!?\"'")


def parse_tasks(tasks_dir: str) -> list[dict]:
    """id, status and verify for every task file. Frontmatter only — no YAML dep."""
    out = []
    if not os.path.isdir(tasks_dir):
        return out
    for fn in sorted(os.listdir(tasks_dir)):
        if not fn.endswith(".md"):
            continue
        text = open(os.path.join(tasks_dir, fn), encoding="utf-8").read()
        if not text.startswith("---"):
            continue
        front = text.split("---", 2)[1]
        field = {}
        for key in ("id", "status", "verify"):
            m = re.search(rf"^{key}:\s*(.*)$", front, re.M)
            field[key] = m.group(1).strip() if m else ""
        field["file"] = fn
        field["id"] = field["id"] or fn[:-3]
        out.append(field)
    return out


def case_names(cases_from: str | None) -> list[str] | None:
    """Every TEST_CASE name the sim test binary exposes, or None if it cannot be read.

    None is not zero. "The binary is not built" and "the binary contains no
    matching tests" are different answers, and conflating them is the exact class
    of bug this checker exists to catch.
    """
    if cases_from:
        with open(cases_from, encoding="utf-8") as f:
            return [ln.strip() for ln in f if ln.strip()]
    if not os.path.isfile(SIM_TESTS) or not os.access(SIM_TESTS, os.X_OK):
        return None
    try:
        r = subprocess.run([SIM_TESTS, "--list-test-cases"],
                           capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    names = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("[doctest]") or set(line) == {"="}:
            continue
        names.append(line)
    return names


def matches(flt: str, names: list[str]) -> list[str]:
    """Replicate doctest's `--test-case=*flt*`: substring, case-insensitive."""
    needle = flt.lower()
    return [n for n in names if needle in n.lower()]


def prefixes(names: list[str]) -> list[str]:
    """The `Rng` in `Rng: forking is reproducible` — what a filter should look like."""
    seen = []
    for n in names:
        p = n.split(":", 1)[0].strip() if ":" in n else n
        if p and p not in seen:
            seen.append(p)
    return seen


def audit(tasks: list[dict], names: list[str]) -> list[tuple[str, str, str, str]]:
    """(verdict, task id, filter, detail) for every task carrying a unit-test filter."""
    rows = []
    for t in tasks:
        verify, tid, status = t["verify"], t["id"], t["status"]

        other = OTHER_FILTER.search(verify)
        if other:
            rows.append(("skip", tid, strip_prose(other.group(2)),
                         f"runs via make {other.group(1)}, not the doctest binary"))
            continue

        m = UNIT_FILTER.search(verify)
        if not m:
            continue
        flt = strip_prose(m.group(1))
        hits = matches(flt, names)

        if hits:
            rows.append(("ok", tid, flt, f"{len(hits)} test case(s)"))
        elif status in VERIFIED_STATUSES:
            rows.append(("error", tid, flt,
                         f"status '{status}' but the filter matches 0 of {len(names)} "
                         f"test cases — this task was never verified by its own command"))
        elif FILE_SHAPED.search(flt):
            rows.append(("suspect", tid, flt,
                         "0 matches, and this names a file, not a test case — "
                         "case names look like 'Rng: ...', so this can never match"))
        else:
            rows.append(("pending", tid, flt,
                         f"0 matches, status '{status}' — expected until the module lands"))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tasks-dir", default=TASKS)
    ap.add_argument("--cases-from", default=None,
                    help="read test-case names from a file instead of the sim binary")
    ap.add_argument("--quiet", action="store_true", help="print errors only")
    args = ap.parse_args()

    names = case_names(args.cases_from)
    if names is None:
        print(f"{C['red']}error{C['off']} cannot read test cases from {SIM_TESTS} — "
              f"run `make build-sim` first. Refusing to report green without looking.")
        return 1

    tasks = parse_tasks(args.tasks_dir)
    rows = audit(tasks, names)

    if not args.quiet:
        print(f"{C['bold']}  {'task':<16}{'filter':<22}verdict{C['off']}")
        mark = {"ok": f"{C['grn']}ok{C['off']}", "pending": f"{C['yel']}--{C['off']}",
                "suspect": f"{C['yel']}??{C['off']}",
                "skip": f"{C['dim']}··{C['off']}", "error": f"{C['red']}!!{C['off']}"}
        for verdict, tid, flt, detail in rows:
            print(f"  {mark[verdict]}  {tid:<16}{flt:<22}{C['dim']}{detail}{C['off']}")
        if names:
            print(f"\n{C['dim']}  test-case name prefixes in the binary: "
                  f"{', '.join(prefixes(names))}{C['off']}")

    for verdict, tid, flt, detail in rows:
        if verdict == "error":
            errors.append(f"tasks/{tid}.md: FILTER={flt}: {detail}")

    for e in errors:
        print(f"{C['red']}error{C['off']} {e}")

    counts = {v: sum(1 for r in rows if r[0] == v)
              for v in ("ok", "pending", "suspect", "skip", "error")}
    print(f"\n{counts['ok']} filter(s) run real tests, {counts['pending']} pending their module, "
          f"{counts['suspect']} named after a file and cannot ever match, "
          f"{counts['skip']} not checkable here, {counts['error']} broken")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
