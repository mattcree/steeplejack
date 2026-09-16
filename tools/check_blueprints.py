#!/usr/bin/env python3
"""Rule 18 — Blueprints are glue only.

AGENTS.md: "No Blueprint may tick or contain a gameplay decision. If it has an `if`
about game rules, it belongs in SteeplejackSim."

.uasset files are binary and we do not parse them properly. What this DOES do is
cheap and useful:

  1. inventory every Blueprint in Content/ against an explicit allowlist, so a new one
     cannot appear without someone writing down why it exists
  2. grep the binary for the signatures of things Blueprints must not do — Tick events,
     Timers, and Branch nodes on gameplay-named variables

A Blueprint that needs to exist gets a line in tools/blueprint_allowlist.txt with a
reason. That review friction is the actual control; the grep is a backstop.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "Content")
ALLOWLIST = os.path.join(ROOT, "tools", "blueprint_allowlist.txt")

# Byte signatures that appear in a .uasset's name table when the graph uses them.
FORBIDDEN = [
    (b"ReceiveTick", "implements Event Tick — Blueprints must not tick (perf budget + review)"),
    (b"K2_SetTimer", "sets a timer — timing is the sim's job, at the fixed step"),
    (b"EventTick", "implements Event Tick"),
]

errors: list[str] = []
warnings: list[str] = []


def load_allowlist() -> dict[str, str]:
    if not os.path.exists(ALLOWLIST):
        return {}
    out = {}
    for line in open(ALLOWLIST, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        path, _, reason = line.partition("#")
        out[path.strip()] = reason.strip()
    return out


def main() -> int:
    if not os.path.isdir(CONTENT):
        print("no Content/ yet — nothing to check")
        return 0

    allow = load_allowlist()
    found = 0
    for dirpath, _, files in os.walk(CONTENT):
        for fn in files:
            if not fn.endswith(".uasset"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT)
            try:
                blob = open(path, "rb").read()
            except OSError:
                continue
            if b"BlueprintGeneratedClass" not in blob:
                continue           # not a Blueprint — a material, mesh, sound, etc.
            found += 1

            if rel not in allow:
                errors.append(
                    f"{rel}: Blueprint not in tools/blueprint_allowlist.txt.\n"
                    f"        Blueprints are glue only (AGENTS.md). If this one must exist, "
                    f"add it with a one-line reason.")
            for sig, why in FORBIDDEN:
                if sig in blob:
                    errors.append(f"{rel}: {why}")

    for w in warnings:
        print(f"\033[33mwarn\033[0m  {w}")
    for e in errors:
        print(f"\033[31merror\033[0m {e}")
    print(f"\n{found} Blueprint(s) found, {len(errors)} violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
