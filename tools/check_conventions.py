#!/usr/bin/env python3
"""Enforce the conventions that agents will otherwise break silently.

See docs/06-workflow/04-enforced-conventions.md. Every check here exists because
the alternative is a sentence in a document that nobody re-reads.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(ROOT, "sim")

errors: list[str] = []

# --- rule 1-3: sim/ purity ---------------------------------------------------
FORBIDDEN_IN_SIM = [
    (r"\bextends\s+(Node|Node2D|Node3D|Control|CanvasItem|Resource|Object)\b",
     "sim/ must not extend engine node types (ADR-0003). Use RefCounted or a plain class."),
    (r"\bget_node\b|\$[A-Za-z_]", "sim/ must not access the scene tree"),
    (r"\brandi\s*\(|\brandf\s*\(|\brandomize\s*\(|\bRandomNumberGenerator\b",
     "sim/ must not use engine RNG — take a seeded Rng as a parameter"),
    (r"\bEngine\.|\bOS\.|\bTime\.|\bInput\.|\bProjectSettings\.",
     "sim/ must not call engine singletons — time and input are parameters"),
    (r"\b_process\s*\(|\b_physics_process\s*\(|\b_ready\s*\(",
     "sim/ must not define engine lifecycle callbacks"),
    (r"\bpreload\s*\(|\bload\s*\(\s*[\"']res://", "sim/ must not load resources"),
]

# --- rule 4: no magic numbers in sim/ ----------------------------------------
ALLOWED_LITERALS = {"0", "1", "-1", "2", "0.0", "1.0", "0.5", "100.0", "2.0", "-1.0"}
NUM = re.compile(r"(?<![\w.])(-?\d+\.?\d*)(?![\w.])")


def check_sim_purity():
    if not os.path.isdir(SIM):
        return
    for dirpath, _, files in os.walk(SIM):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
            for i, line in enumerate(open(os.path.join(dirpath, fn), encoding="utf-8"), 1):
                code = line.split("#")[0]
                for pat, msg in FORBIDDEN_IN_SIM:
                    if re.search(pat, code):
                        errors.append(f"{rel}:{i}: {msg}")
                # magic numbers
                if "# literal:" in line:
                    continue
                if re.match(r"\s*(const|@export)\b", code):
                    continue
                for m in NUM.finditer(code):
                    tok = m.group(1)
                    if tok in ALLOWED_LITERALS:
                        continue
                    before = code[max(0, m.start() - 1):m.start()]
                    if before == "[":          # array index
                        continue
                    errors.append(
                        f"{rel}:{i}: magic number {tok!r} — move it to data/tuning/*.json "
                        f"or annotate the line with '# literal: <reason>' "
                        f"(docs/06-workflow/04-enforced-conventions.md rule 4)")


# --- rule 16: likeness ------------------------------------------------------
def check_likeness():
    base = os.path.join(ROOT, "tools", "likeness_denylist.txt")
    local = os.path.join(ROOT, "tools", "likeness_denylist.local.txt")
    if not os.path.exists(base):
        errors.append("tools/likeness_denylist.txt is missing — rule 16 cannot run")
        return
    terms: list[str] = []
    for path in (base, local):
        if not os.path.exists(path):
            continue
        terms += [t.strip() for t in open(path, encoding="utf-8")
                  if t.strip() and not t.startswith("#")]
    if not terms:
        print("\033[33mnote\033[0m  rule 16 (likeness) is INERT — no terms configured. "
              "Populate tools/likeness_denylist.local.txt before M0. "
              "See docs/05-legal/ip-and-likeness.md")
        return
    skip_dirs = {".git", ".godot", "build", "dist", "node_modules"}
    for dirpath, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for fn in files:
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT)
            if rel.startswith("tools/likeness_denylist.txt"):
                continue
            if os.path.splitext(fn)[1] not in {".gd", ".md", ".json", ".tscn", ".tres",
                                               ".txt", ".yml", ".yaml", ".gdshader", ".cfg", ""}:
                continue
            try:
                text = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            low = text.lower()
            for term in terms:
                if term.lower() in low:
                    errors.append(
                        f"{rel}: contains a denied name/phrase ({term!r}) — "
                        f"see docs/05-legal/ip-and-likeness.md")

    # history too — a rewritten file still leaves the name in the log
    try:
        log = subprocess.run(["git", "log", "--pretty=%s%n%b"], cwd=ROOT,
                             capture_output=True, text=True, timeout=30).stdout.lower()
        for term in terms:
            if term.lower() in log:
                errors.append(f"git history: commit messages contain {term!r} "
                              f"— see docs/05-legal/ip-and-likeness.md")
    except (OSError, subprocess.SubprocessError):
        pass


# --- rule 10: tuning keys referenced by sim/ exist ---------------------------
def check_tuning_keys():
    import json
    tuning_dir = os.path.join(ROOT, "data", "tuning")
    if not os.path.isdir(tuning_dir) or not os.path.isdir(SIM):
        return
    keys: set[str] = set()

    def collect(o, prefix=""):
        if isinstance(o, dict):
            for k, v in o.items():
                keys.add(k)
                collect(v, k)

    for fn in os.listdir(tuning_dir):
        if fn.endswith(".json"):
            collect(json.load(open(os.path.join(tuning_dir, fn), encoding="utf-8")))

    ref = re.compile(r"\btuning\.([a-zA-Z_][a-zA-Z0-9_]*)")
    for dirpath, _, files in os.walk(SIM):
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
            for i, line in enumerate(open(os.path.join(dirpath, fn), encoding="utf-8"), 1):
                for m in ref.finditer(line.split("#")[0]):
                    snake = m.group(1)
                    camel = re.sub(r"_([a-z])", lambda x: x.group(1).upper(), snake)
                    if snake not in keys and camel not in keys:
                        errors.append(f"{rel}:{i}: tuning key {snake!r} not found in "
                                      f"data/tuning/*.json")


def main():
    check_sim_purity()
    check_tuning_keys()
    check_likeness()
    for e in errors:
        print(f"\033[31merror\033[0m {e}")
    print(f"\n{len(errors)} convention violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
