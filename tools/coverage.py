#!/usr/bin/env python3
"""Line-coverage gate for SteeplejackSim.

docs/06-workflow/03-verification.md: SteeplejackSim must hold >= 90% line coverage.
The Godot layer (godot/, Source/SteeplejackGodot) is deliberately NOT gated — it is
presentation, checked by make godot-test and by looking at frames. That asymmetry is the
point of the module split.

Uses gcov/llvm-cov via a separate instrumented build so the normal build stays fast.

    python3 tools/coverage.py            # gate at 90%
    python3 tools/coverage.py --report   # per-file breakdown, no gate
    python3 tools/coverage.py --gate 99  # a gate the sim cannot meet: must exit non-zero
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build-coverage")
SIM = os.path.join(ROOT, "Source", "SteeplejackSim")
THRESHOLD = 90.0   # `--gate N` overrides it, which is how the gate's own failure is proved


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, **kw)


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def main() -> int:
    global THRESHOLD
    report_only = "--report" in sys.argv
    if "--gate" in sys.argv:
        THRESHOLD = float(sys.argv[sys.argv.index("--gate") + 1])

    sources = [f for _, _, fs in os.walk(os.path.join(SIM, "Private"))
               for f in fs if f.endswith(".cpp")]
    if not sources:
        print("SteeplejackSim has no modules yet — coverage gate is not applicable.")
        print("This becomes meaningful at CORE-003. Passing.")
        return 0

    # A gate that cannot measure must not pass: that is how a coverage gate turns into
    # decoration without anyone noticing. Same rule as test-unit's zero-match filter (TEST-003).
    if not have("gcov"):
        print("\033[31merror\033[0m gcov not found — coverage cannot be measured, so it cannot pass")
        print("        install gcc's gcov (CI installs lcov, which brings it)")
        return 1

    print("building instrumented...")
    r = sh(["cmake", "-B", BUILD, "-DCMAKE_BUILD_TYPE=Debug",
            "-DCMAKE_CXX_FLAGS=--coverage -O0 -g",
            "-DCMAKE_EXE_LINKER_FLAGS=--coverage"])
    if r.returncode:
        print(r.stderr[-2000:])
        return 1
    # Counts from an earlier run would be added to this one's.
    for dirpath, _, files in os.walk(BUILD):
        for f in files:
            if f.endswith(".gcda"):
                os.remove(os.path.join(dirpath, f))
    r = sh(["cmake", "--build", BUILD, "-j"])
    if r.returncode:
        print(r.stderr[-2000:])
        return 1

    r = sh([os.path.join(BUILD, "sim_tests")])
    if r.returncode:
        print("tests failed under instrumentation — fix the tests first")
        print(r.stdout[-2000:])
        return 1

    per_file = measure()
    if not per_file:
        print("\033[31merror\033[0m gcov produced no data for SteeplejackSim — nothing was "
              "measured, so the gate cannot pass")
        return 1

    covered = sum(c for c, _ in per_file.values())
    total_lines = sum(n for _, n in per_file.values())
    total = 100.0 * covered / total_lines
    width = max(len(k) for k in per_file)
    print()
    for f, (c, n) in sorted(per_file.items(), key=lambda kv: kv[1][0] / kv[1][1]):
        pct = 100.0 * c / n
        colour = "\033[32m" if pct >= THRESHOLD else "\033[31m"
        print(f"  {f:<{width}}  {colour}{pct:5.1f}%\033[0m  {c:>4}/{n:<4}")
    print(f"\n  {'TOTAL':<{width}}  {total:5.1f}%  {covered:>4}/{total_lines:<4} lines"
          f"   (gate: {THRESHOLD}%)")

    if report_only:
        return 0
    if total < THRESHOLD:
        print(f"\n\033[31merror\033[0m SteeplejackSim coverage {total:.1f}% is below "
              f"the {THRESHOLD}% gate")
        print("        The sim holds every gameplay decision. Untested branches there are "
              "untested game rules.")
        return 1
    return 0


def measure() -> dict[str, tuple[int, int]]:
    """Covered and total executable lines for every file under Source/SteeplejackSim.

    gcov's JSON, one data file per translation unit of the sim library only — the tests' own
    lines are not the sim's coverage. A header is compiled into many units, so a line counts as
    covered if any unit ran it. Weighted by lines, not averaged per file: a ten-line file must not
    count as much as a four-hundred-line one.
    """
    import json
    objdir = os.path.join(BUILD, "CMakeFiles", "steeplejack_sim.dir")
    data = [os.path.join(d, f) for d, _, fs in os.walk(objdir) for f in fs if f.endswith(".gcda")]
    lines: dict[str, dict[int, int]] = {}
    for gcda in data:
        r = sh(["gcov", "--json-format", "--stdout", gcda])
        for doc in r.stdout.splitlines():
            if not doc.strip():
                continue
            for f in json.loads(doc).get("files", []):
                path = os.path.normpath(os.path.join(ROOT, f["file"]))
                if not path.startswith(SIM + os.sep):
                    continue
                seen = lines.setdefault(os.path.relpath(path, ROOT), {})
                for ln in f["lines"]:
                    seen[ln["line_number"]] = max(seen.get(ln["line_number"], 0), ln["count"])
    return {f: (sum(1 for c in ls.values() if c > 0), len(ls)) for f, ls in lines.items() if ls}


if __name__ == "__main__":
    sys.exit(main())
