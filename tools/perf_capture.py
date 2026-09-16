#!/usr/bin/env python3
"""Frame-time capture on the three reference scenes.

docs/03-tech/performance-budget.md defines the budgets. This drives a headless Unreal
run with -benchmark over each reference scene, appends to perf-history.csv, and fails
on a regression over 10%.

Requires UE_ROOT. Nightly, not per-commit — the per-commit performance check is the
Sim::Step budget, which runs in the standalone build with no engine at all.

    UE_ROOT=/opt/UnrealEngine python3 tools/perf_capture.py
    python3 tools/perf_capture.py --check-only     # re-check the CSV, no capture
"""
from __future__ import annotations

import csv
import datetime
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HISTORY = os.path.join(ROOT, "docs", "03-tech", "perf-history.csv")
PROJECT = os.path.join(ROOT, "Steeplejack.uproject")
REGRESSION = 1.10          # fail over +10%

# (scene id, level id, budget ms). Budgets from docs/03-tech/performance-budget.md.
SCENES = [
    ("trivial",  "01-back-yard",  16.6),
    ("bricks",   "09-dye-house-twins", 16.6),
    ("the-fall", "12-great-aire", 33.0),   # the deliberate spike; 30 fps is acceptable
]
FIELDS = ["date", "commit", "scene", "mean_ms", "p95_ms", "budget_ms"]


def git_sha() -> str:
    r = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                       capture_output=True, text=True)
    return r.stdout.strip() or "unknown"


def read_history() -> list[dict]:
    if not os.path.exists(HISTORY):
        return []
    with open(HISTORY, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def check(rows: list[dict]) -> int:
    errors = []
    for scene, _, budget in SCENES:
        hist = [r for r in rows if r["scene"] == scene]
        if not hist:
            continue
        latest = float(hist[-1]["p95_ms"])
        if latest > budget:
            errors.append(f"{scene}: p95 {latest:.1f} ms exceeds the {budget} ms budget")
        if len(hist) >= 2:
            prev = float(hist[-2]["p95_ms"])
            if prev > 0 and latest / prev > REGRESSION:
                errors.append(f"{scene}: p95 regressed {((latest/prev)-1)*100:.0f}% "
                              f"({prev:.1f} -> {latest:.1f} ms)")
    for e in errors:
        print(f"\033[31merror\033[0m {e}")
    print(f"\n{len(errors)} performance regression(s)")
    return 1 if errors else 0


def main() -> int:
    rows = read_history()
    if "--check-only" in sys.argv:
        return check(rows)

    ue = os.environ.get("UE_ROOT")
    if not ue:
        print("UE_ROOT is not set — cannot capture.")
        print("This is a nightly job that needs Unreal. The per-commit performance check is")
        print("the Sim::Step budget (`make test-perf`), which needs no engine.")
        return 1

    cmd_bin = os.path.join(ue, "Engine", "Binaries", "Linux", "UnrealEditor-Cmd")
    new: list[dict] = []
    for scene, level, budget in SCENES:
        print(f"capturing {scene} ({level})...")
        r = subprocess.run(
            [cmd_bin, PROJECT, f"-ExecCmds=SteeplejackLoadLevel {level}; Automation RunTests "
                               f"Steeplejack.Perf.{scene}; Quit",
             "-benchmark", "-unattended", "-nosplash", "-deterministic"],
            capture_output=True, text=True, timeout=1800)
        mean = p95 = 0.0
        for line in r.stdout.splitlines():
            if "PERF mean_ms=" in line:
                mean = float(line.split("mean_ms=")[1].split()[0])
            if "PERF p95_ms=" in line:
                p95 = float(line.split("p95_ms=")[1].split()[0])
        if p95 == 0.0:
            print(f"\033[33mwarn\033[0m  {scene}: no PERF line in output — capture failed")
            continue
        new.append({"date": datetime.date.today().isoformat(), "commit": git_sha(),
                    "scene": scene, "mean_ms": f"{mean:.2f}", "p95_ms": f"{p95:.2f}",
                    "budget_ms": f"{budget}"})

    if new:
        exists = os.path.exists(HISTORY)
        os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
        with open(HISTORY, "a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            if not exists:
                w.writeheader()
            w.writerows(new)
        rows += new

    return check(rows)


if __name__ == "__main__":
    sys.exit(main())
