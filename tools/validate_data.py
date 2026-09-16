#!/usr/bin/env python3
"""Validate level and tuning data.

Runs without Unreal and without a compiler, in about a second, so it can sit in a pre-commit hook.
Checks the JSON Schema plus the design rules that a schema cannot express —
notably the Ascent Beat Rule, which exists to defend against risk R1.
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVELS = os.path.join(ROOT, "data", "levels")
TUNING = os.path.join(ROOT, "data", "tuning")
SCHEMA = os.path.join(ROOT, "data", "schemas", "level.schema.json")

MAX_PLAIN_BAND_M = 20.0          # Ascent Beat Rule
QUALITY_TOLERANCE = 0.001
MAX_SPAN_M = 6.0                 # reachability assumption; see climbing.json spanWarnMetres

errors: list[str] = []
warnings: list[str] = []


def err(f, m):
    errors.append(f"{f}: {m}")


def warn(f, m):
    warnings.append(f"{f}: {m}")


def schema_validate(doc, name):
    try:
        import jsonschema  # type: ignore
    except ImportError:
        warn(name, "jsonschema not installed — schema check skipped (pip install jsonschema)")
        return
    schema = json.load(open(SCHEMA, encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema)
    for e in sorted(validator.iter_errors(doc), key=lambda x: list(x.path)):
        err(name, f"schema: {'/'.join(str(p) for p in e.path) or '<root>'}: {e.message}")


def check_bands(doc, name):
    """Contiguity, coverage, quality sums, and the Ascent Beat Rule."""
    height = doc["structure"]["height"]
    bands = doc["bands"]
    cursor = 0.0
    for i, b in enumerate(bands):
        if abs(b["from"] - cursor) > 1e-6:
            err(name, f"band {i} ({b['type']}) starts at {b['from']}m, expected {cursor}m "
                      f"— bands must be contiguous")
        if b["to"] <= b["from"]:
            err(name, f"band {i} ({b['type']}) has non-positive extent")
        cursor = b["to"]

        q = b["quality"]
        total = sum(q.values())
        if abs(total - 1.0) > QUALITY_TOLERANCE:
            err(name, f"band {i} ({b['type']}) quality sums to {total:.4f}, must be 1.0")

        span = b["to"] - b["from"]
        if b["type"] == "plain" and span > MAX_PLAIN_BAND_M:
            err(name, f"band {i} is 'plain' and {span:.1f}m long — Ascent Beat Rule allows "
                      f"{MAX_PLAIN_BAND_M}m max. Split it or give it a character. "
                      f"(docs/01-gdd/01-core-loop.md#the-ascent-beat-rule)")

    if abs(cursor - height) > 1e-6:
        err(name, f"bands cover 0–{cursor}m but the structure is {height}m tall")


def check_reachability(doc, name):
    """Cheap static check: can the ladder allowance plausibly reach the top?

    The real solver is tests/reachability (needs the joint grid). This catches the
    common authoring mistake of specifying too few ladders for the height.
    """
    height = doc["structure"]["height"]
    hint = doc.get("loadoutHint", {})
    ladders = hint.get("ladders")
    if ladders is None:
        warn(name, "no loadoutHint.ladders — cannot sanity-check reachability")
        return

    internal = sum(b["to"] - b["from"] for b in doc["bands"] if b["type"] == "internal")
    climbed = height - internal
    # 4.0m effective rise per section at the comfortable span
    comfortable = ladders * 4.0
    limit = ladders * MAX_SPAN_M
    if limit < climbed:
        err(name, f"{ladders} ladders cannot reach {climbed:.0f}m of climbing even at the "
                  f"{MAX_SPAN_M}m danger span (max {limit:.0f}m)")
    elif comfortable < climbed:
        need = climbed / ladders
        warn(name, f"{ladders} ladders for {climbed:.0f}m forces a {need:.1f}m average span "
                   f"— intentional pressure, or a mistake?")


def check_felling(doc, name):
    site = doc.get("site", {})
    corridor = site.get("corridor")
    if not corridor:
        if doc["archetype"] == "FELL":
            err(name, "FELL level has no site.corridor")
        return

    def in_corridor(b):
        lo, hi = corridor["fromBearing"], corridor["toBearing"]
        return lo <= b <= hi if lo <= hi else (b >= lo or b <= hi)

    for ex in site.get("exclusions") or []:
        if in_corridor(ex["bearing"]):
            err(name, f"exclusion '{ex['id']}' at bearing {ex['bearing']}° sits inside the fall "
                      f"corridor {corridor['fromBearing']}–{corridor['toBearing']}° "
                      f"— this level is unwinnable")

    if doc["archetype"] == "FELL":
        h = doc["structure"]["height"]
        safe = site.get("safeLineDistance", 0)
        if safe < h * 1.5:
            err(name, f"safeLineDistance {safe}m is under 1.5x height ({h * 1.5:.0f}m)")


def check_scoring(doc, name):
    known = {"angularError", "collateralValue", "shiftRemaining", "fractureCount", "defectsFound",
             "craftsmanshipGrade", "bricksSalvaged", "toolsDropped", "reworkCount",
             "heightRemoved", "materialsRecovered", "leavesWasted"}
    import re
    for b in doc["scoring"]["bonuses"]:
        for ident in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", b["condition"]):
            if ident in ("and", "or", "not", "true", "false"):
                continue
            if ident not in known:
                err(name, f"bonus '{b['id']}' references unknown job-record field {ident!r}")


def check_docs_link(doc, name):
    dd = doc.get("designDoc")
    if not dd:
        warn(name, "no designDoc link")
    elif not os.path.exists(os.path.join(ROOT, dd)):
        err(name, f"designDoc does not exist: {dd}")


def check_tuning():
    for fn in sorted(os.listdir(TUNING)):
        if not fn.endswith(".json"):
            continue
        p = os.path.join(TUNING, fn)
        try:
            doc = json.load(open(p, encoding="utf-8"))
        except json.JSONDecodeError as e:
            err(fn, f"invalid JSON: {e}")
            continue

        def walk(o, path=""):
            if isinstance(o, dict):
                for k, v in o.items():
                    walk(v, f"{path}.{k}" if path else k)
            elif isinstance(o, list):
                for i, v in enumerate(o):
                    walk(v, f"{path}[{i}]")
            elif isinstance(o, bool) or o is None:
                pass
            elif isinstance(o, (int, float)):
                pass
            elif isinstance(o, str):
                pass
            else:
                err(fn, f"{path}: unexpected type {type(o).__name__}")

        walk(doc)


def main():
    if not os.path.exists(SCHEMA):
        print(f"missing schema: {SCHEMA}")
        return 1

    n = 0
    for fn in sorted(os.listdir(LEVELS)):
        if not fn.endswith(".json"):
            continue
        n += 1
        p = os.path.join(LEVELS, fn)
        try:
            doc = json.load(open(p, encoding="utf-8"))
        except json.JSONDecodeError as e:
            err(fn, f"invalid JSON: {e}")
            continue
        schema_validate(doc, fn)
        try:
            check_bands(doc, fn)
            check_reachability(doc, fn)
            check_felling(doc, fn)
            check_scoring(doc, fn)
            check_docs_link(doc, fn)
        except KeyError as e:
            err(fn, f"missing key {e} — fix schema errors first")

    check_tuning()

    for w in warnings:
        print(f"\033[33mwarn\033[0m  {w}")
    for e in errors:
        print(f"\033[31merror\033[0m {e}")
    print(f"\n{n} level(s) checked, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
