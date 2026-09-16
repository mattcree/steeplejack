#!/usr/bin/env python3
"""Check that every relative link in the documentation resolves.

Docs are the spec, and the spec is navigated by links. A broken link is a
work item that can't find its context.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {".git", ".godot", "build", "dist", "node_modules"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")

bad = []
for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP]
    for fn in files:
        if not fn.endswith(".md"):
            continue
        path = os.path.join(dirpath, fn)
        rel = os.path.relpath(path, ROOT)
        for link in LINK.findall(open(path, encoding="utf-8").read()):
            if link.startswith(("http://", "https://", "#", "mailto:")):
                continue
            target = os.path.normpath(os.path.join(dirpath, link.split("#")[0]))
            if not os.path.exists(target):
                bad.append((rel, link))

for f, link in bad:
    print(f"\033[31merror\033[0m {f} -> {link}")
print(f"\n{len(bad)} broken link(s)")
sys.exit(1 if bad else 0)
