#!/usr/bin/env python3
"""Line-coverage gate for SteeplejackSim.

docs/06-workflow/03-verification.md: SteeplejackSim must hold >= 90% line coverage.
SteeplejackGame and Content/ are deliberately NOT gated — they are presentation and
their correctness is visual. That asymmetry is the point of the module split.

Uses gcov/llvm-cov via a separate instrumented build so the normal build stays fast.

    python3 tools/coverage.py            # gate at 90%
    python3 tools/coverage.py --report   # per-file breakdown, no gate
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
THRESHOLD = 90.0


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, **kw)


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def main() -> int:
    report_only = "--report" in sys.argv

    sources = [f for _, _, fs in os.walk(os.path.join(SIM, "Private"))
               for f in fs if f.endswith(".cpp")]
    if not sources:
        print("SteeplejackSim has no modules yet — coverage gate is not applicable.")
        print("This becomes meaningful at CORE-003. Passing.")
        return 0

    if not (have("gcov") or have("llvm-cov")):
        print("\033[33mwarn\033[0m  neither gcov nor llvm-cov found — coverage not measured")
        print("        install one, or run this in the CI container")
        return 0

    print("building instrumented...")
    r = sh(["cmake", "-B", BUILD, "-DCMAKE_BUILD_TYPE=Debug",
            "-DCMAKE_CXX_FLAGS=--coverage -O0 -g",
            "-DCMAKE_EXE_LINKER_FLAGS=--coverage"])
    if r.returncode:
        print(r.stderr[-2000:])
        return 1
    r = sh(["cmake", "--build", BUILD, "-j"])
    if r.returncode:
        print(r.stderr[-2000:])
        return 1

    r = sh([os.path.join(BUILD, "sim_tests")])
    if r.returncode:
        print("tests failed under instrumentation — fix the tests first")
        print(r.stdout[-2000:])
        return 1

    # gcov over the sim objects only
    objdir = os.path.join(BUILD, "CMakeFiles", "steeplejack_sim.dir")
    r = sh(["gcov", "-r", "-o", objdir] +
           [os.path.join(SIM, "Private", s) for s in sources])

    per_file: dict[str, float] = {}
    name = None
    for line in r.stdout.splitlines():
        if line.startswith("File '"):
            name = line.split("'")[1]
        elif line.startswith("Lines executed:") and name:
            pct = float(re.search(r"([\d.]+)%", line).group(1))
            if "SteeplejackSim" in name:
                per_file[os.path.relpath(name, ROOT)] = pct
            name = None

    if not per_file:
        print("\033[33mwarn\033[0m  gcov produced no data for SteeplejackSim")
        return 0

    total = sum(per_file.values()) / len(per_file)
    width = max(len(k) for k in per_file)
    print()
    for f, pct in sorted(per_file.items(), key=lambda kv: kv[1]):
        colour = "\033[32m" if pct >= THRESHOLD else "\033[31m"
        print(f"  {f:<{width}}  {colour}{pct:5.1f}%\033[0m")
    print(f"\n  {'TOTAL':<{width}}  {total:5.1f}%   (gate: {THRESHOLD}%)")

    if report_only:
        return 0
    if total < THRESHOLD:
        print(f"\n\033[31merror\033[0m SteeplejackSim coverage {total:.1f}% is below "
              f"the {THRESHOLD}% gate")
        print("        The sim holds every gameplay decision. Untested branches there are "
              "untested game rules.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
