#!/usr/bin/env python3
"""Task graph tooling.

Tasks are markdown files with YAML frontmatter in tasks/. One file per task means
parallel agents never conflict on a shared board. The board is computed, never stored.

  tasks.py validate   check frontmatter, deps, ownership conflicts, spec refs
  tasks.py board      status overview
  tasks.py ready      tasks whose dependencies are all done
  tasks.py waves      dependency-ordered execution waves
  tasks.py editor     tasks needing a human at an editor (art, animation)
  tasks.py human      ALL work a human must do (editor, recording, playtests)
  tasks.py critical   longest dependency chain by estimate days [TARGET]
  tasks.py stale      in_progress tasks with an empty Outcome
  tasks.py graph      mermaid dependency graph
  tasks.py new ID "Title"
"""
from __future__ import annotations

import fnmatch
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASK_DIR = os.path.join(ROOT, "tasks")

STATUSES = ["draft", "ready", "claimed", "in_progress", "blocked", "review", "done", "cut"]
# A dependency in one of these no longer holds anything up: finished, or never going to happen.
RESOLVED = ("done", "cut")
DISCIPLINES = ["ENG", "DES", "ART", "AUD", "TECH-ART", "PROD"]
REQUIRED = ["id", "title", "milestone", "discipline", "estimate_days", "status",
            "depends_on", "owns", "verify", "editor_required"]

C = {"red": "\033[31m", "grn": "\033[32m", "ylw": "\033[33m", "blu": "\033[34m",
     "dim": "\033[2m", "bold": "\033[1m", "off": "\033[0m"}
if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    C = {k: "" for k in C}


def parse_scalar(v: str):
    v = v.strip()
    if v in ("null", "~", ""):
        return None
    if v in ("true", "True"):
        return True
    if v in ("false", "False"):
        return False
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        return [] if not inner else [x.strip().strip("'\"") for x in inner.split(",")]
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d*\.\d+", v):
        return float(v)
    return v.strip("'\"")


def parse_frontmatter(text: str) -> dict:
    """Minimal YAML subset: scalars, inline lists, and block lists. No nesting."""
    if not text.startswith("---"):
        raise ValueError("no frontmatter")
    end = text.index("\n---", 3)
    body = text[3:end]
    data, key = {}, None
    for raw in body.splitlines():
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        if raw.startswith("  - ") or raw.startswith("- "):
            if key is None:
                raise ValueError("list item before key")
            data.setdefault(key, [])
            if not isinstance(data[key], list):
                data[key] = []
            data[key].append(raw.split("- ", 1)[1].strip().strip("'\""))
            continue
        if ":" not in raw:
            raise ValueError(f"bad line: {raw!r}")
        k, _, v = raw.partition(":")
        key = k.strip()
        data[key] = parse_scalar(v) if v.strip() else []
    return data


def sections(text: str) -> dict:
    out, cur = {}, None
    for line in text.splitlines():
        if line.startswith("## "):
            cur = line[3:].strip().lower()
            out[cur] = []
        elif cur:
            out[cur].append(line)
    return {k: "\n".join(v).strip() for k, v in out.items()}


def load() -> list[dict]:
    tasks = []
    if not os.path.isdir(TASK_DIR):
        return tasks
    for fn in sorted(os.listdir(TASK_DIR)):
        if not fn.endswith(".md") or fn.startswith("TASK-TEMPLATE"):
            continue
        p = os.path.join(TASK_DIR, fn)
        text = open(p, encoding="utf-8").read()
        try:
            fm = parse_frontmatter(text)
        except Exception as e:  # noqa: BLE001
            print(f"{C['red']}{fn}: unparseable frontmatter: {e}{C['off']}")
            sys.exit(1)
        fm["_file"] = fn
        fm["_sections"] = sections(text)
        tasks.append(fm)
    return tasks


def index(tasks):
    return {t["id"]: t for t in tasks}


def ancestors(tid, by_id, seen=None):
    seen = seen or set()
    for d in by_id.get(tid, {}).get("depends_on", []) or []:
        if d in seen:
            continue
        seen.add(d)
        ancestors(d, by_id, seen)
    return seen


def related(a, b, by_id):
    """True if a and b are connected by a dependency chain (so cannot run concurrently)."""
    return b in ancestors(a, by_id) or a in ancestors(b, by_id)


def globs_overlap(a: str, b: str) -> bool:
    if a == b:
        return True
    return fnmatch.fnmatch(a, b) or fnmatch.fnmatch(b, a) or \
        a.rstrip("*").startswith(b.rstrip("*")) and b.endswith("**") or \
        b.rstrip("*").startswith(a.rstrip("*")) and a.endswith("**")


def cmd_validate(tasks):
    by_id, errors, warnings = index(tasks), [], []

    for t in tasks:
        fid = t["_file"]
        for f in REQUIRED:
            if f not in t:
                errors.append(f"{fid}: missing required field '{f}'")
        if t.get("status") not in STATUSES:
            errors.append(f"{fid}: bad status {t.get('status')!r}")
        for d in t.get("discipline") or []:
            if d not in DISCIPLINES:
                errors.append(f"{fid}: unknown discipline {d!r}")
        if t.get("id") and t["_file"] != f"{t['id']}.md":
            errors.append(f"{fid}: filename must be {t['id']}.md")
        for dep in t.get("depends_on") or []:
            if dep not in by_id:
                errors.append(f"{fid}: depends_on unknown task {dep}")
        for s in t.get("spec") or []:
            path = os.path.join(ROOT, s.split("#")[0])
            if not os.path.exists(path):
                errors.append(f"{fid}: spec ref does not exist: {s}")
        if not (t.get("owns") or []):
            errors.append(f"{fid}: owns is empty")

        # Definition of Ready
        if t.get("status") in ("ready", "claimed", "in_progress", "review", "done"):
            for sec in ("goal", "why", "acceptance"):
                if not t["_sections"].get(sec):
                    errors.append(f"{fid}: status={t['status']} but '## {sec.title()}' is empty")
            if not t.get("verify"):
                errors.append(f"{fid}: status={t['status']} but no verify command")
        if t.get("status") == "blocked" and not t["_sections"].get("blocked"):
            errors.append(f"{fid}: blocked but '## Blocked' is empty")
        if t.get("status") in ("review", "done") and not t["_sections"].get("outcome"):
            errors.append(f"{fid}: status={t['status']} but '## Outcome' is empty")
        # 'ready' means the task FILE is complete (Definition of Ready). Whether it is
        # claimable is a separate question, computed by `tasks.py ready`. But a task that is
        # actually being worked while a dependency is unfinished is a real problem.
        if t.get("status") in ("claimed", "in_progress"):
            for dep in t.get("depends_on") or []:
                if by_id.get(dep, {}).get("status") not in RESOLVED:
                    warnings.append(
                        f"{fid}: {t['status']} but dependency {dep} is "
                        f"{by_id.get(dep, {}).get('status', 'missing')}")
        try:
            if float(t.get("estimate_days", 0)) > 3 and not t["_sections"].get("context", "").lower().count("risk"):
                warnings.append(f"{fid}: estimate {t['estimate_days']}d > 3 — consider splitting "
                                f"(or name the risk and the fallback in ## Context)")
        except (TypeError, ValueError):
            errors.append(f"{fid}: estimate_days is not a number")

    # cycles
    colour = {}

    def visit(n, path):
        if colour.get(n) == 2:
            return
        if colour.get(n) == 1:
            errors.append("dependency cycle: " + " -> ".join(path + [n]))
            return
        colour[n] = 1
        for d in by_id.get(n, {}).get("depends_on", []) or []:
            if d in by_id:
                visit(d, path + [n])
        colour[n] = 2

    for t in tasks:
        visit(t["id"], [])

    # ownership conflicts between tasks that could run concurrently
    for i, a in enumerate(tasks):
        for b in tasks[i + 1:]:
            if a.get("status") in ("done", "cut") or b.get("status") in ("done", "cut"):
                continue
            if related(a["id"], b["id"], by_id):
                continue
            shared = [x for x in (a.get("owns") or []) for y in (b.get("owns") or [])
                      if globs_overlap(x, y)]
            if shared:
                errors.append(
                    f"ownership conflict: {a['id']} and {b['id']} both own "
                    f"{sorted(set(shared))[0]!r} and neither depends on the other")

    for w in warnings:
        print(f"{C['ylw']}warn{C['off']}  {w}")
    for e in errors:
        print(f"{C['red']}error{C['off']} {e}")
    print(f"\n{len(tasks)} tasks, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


def cmd_board(tasks):
    by_ms = defaultdict(lambda: defaultdict(list))
    for t in tasks:
        by_ms[t["milestone"]][t["status"]].append(t)
    cols = ["draft", "ready", "in_progress", "blocked", "review", "done", "cut"]
    print(f"{C['bold']}{'milestone':<10}" + "".join(f"{c:>13}" for c in cols) + f"{'days':>8}{C['off']}")
    for ms in sorted(by_ms):
        row = by_ms[ms]
        days = sum(float(t.get("estimate_days") or 0) for s in cols for t in row[s])
        done = sum(float(t.get("estimate_days") or 0) for t in row["done"])
        print(f"{ms:<10}" + "".join(f"{len(row[c]) or '':>13}" for c in cols) +
              f"{done:>5.0f}/{days:<3.0f}")
    total = sum(float(t.get("estimate_days") or 0) for t in tasks)
    done = sum(float(t.get("estimate_days") or 0) for t in tasks if t["status"] == "done")
    pct = (done / total * 100) if total else 0
    print(f"\n{C['bold']}{done:.0f} / {total:.0f} ideal days  ({pct:.0f}%){C['off']}")
    blocked = [t for t in tasks if t["status"] == "blocked"]
    if blocked:
        print(f"\n{C['red']}BLOCKED{C['off']}")
        for t in blocked:
            print(f"  {t['id']:<12} {t['title']}")
    review = [t for t in tasks if t["status"] == "review"]
    if review:
        print(f"\n{C['ylw']}AWAITING REVIEW ({len(review)}){C['off']}")
        for t in review:
            print(f"  {t['id']:<12} {t['title']}")
        if len(review) > 3:
            print(f"  {C['ylw']}review queue is long — stop claiming, start reviewing{C['off']}")
    return 0


def is_human(t) -> bool:
    """Work an agent cannot do: an art or animation editor, a recording booth, a playtest room."""
    return bool(t.get("editor_required")) or bool(t.get("human_required"))


def ready_tasks(tasks, human=None):
    """human=None: all. human=False: agent-claimable. human=True: human-only."""
    by_id = index(tasks)
    out = []
    for t in tasks:
        if t["status"] not in ("ready", "draft"):
            continue
        # A cut dependency is work that will never happen, so nothing waits for it.
        if not all(by_id.get(d, {}).get("status") in RESOLVED for d in (t.get("depends_on") or [])):
            continue
        if human is not None and is_human(t) != human:
            continue
        out.append(t)
    return out


def _print_rows(rows):
    for t in sorted(rows, key=lambda x: (x["milestone"], x["id"])):
        flag = f"{C['ylw']}[draft]{C['off']} " if t["status"] == "draft" else ""
        disc = ",".join(t.get("discipline") or [])
        print(f"  {t['id']:<12} {flag}{t['title'][:52]:<54}{C['dim']}{disc:<10}"
              f"{t['estimate_days']}d{C['off']}")


def cmd_ready(tasks):
    agent = ready_tasks(tasks, human=False)
    human = ready_tasks(tasks, human=True)

    if agent:
        print(f"{C['bold']}{C['grn']}AGENT-CLAIMABLE ({len(agent)}){C['off']}  "
              f"{C['dim']}— an agent can do these start to finish{C['off']}")
        _print_rows(agent)
    else:
        print(f"{C['ylw']}Nothing agent-claimable.{C['off']} Check `make board` for blocked "
              f"or in-review work, and `make human-queue`.")

    if human:
        print(f"\n{C['bold']}{C['blu']}NEEDS A HUMAN ({len(human)}){C['off']}  "
              f"{C['dim']}— an art tool, a recording, or a room full of testers{C['off']}")
        _print_rows(human)
        days = sum(float(t.get("estimate_days") or 0) for t in human)
        print(f"  {C['dim']}{days:.1f} ideal days queued for one human. This is risk R8's "
              f"gauge.{C['off']}")

    if any(t["status"] == "draft" for t in agent + human):
        print(f"\n{C['dim']}[draft] tasks are not Ready — complete the task file first "
              f"(see docs/06-workflow/01-work-items.md){C['off']}")
    return 0


def cmd_human(tasks):
    q = [t for t in tasks if is_human(t) and t["status"] not in ("done", "cut")]
    if not q:
        print("nothing needs a human")
        return 0
    days = sum(float(t.get("estimate_days") or 0) for t in q)
    by_id = index(tasks)
    print(f"{C['bold']}{len(q)} task(s) need a human · {days:.1f} ideal days{C['off']}\n")
    for t in sorted(q, key=lambda x: (x["milestone"], x["id"])):
        blocked = [d for d in (t.get("depends_on") or [])
                   if by_id.get(d, {}).get("status") != "done"]
        gate = f"{C['dim']}waiting on {','.join(blocked)}{C['off']}" if blocked else \
            f"{C['grn']}ready now{C['off']}"
        kind = "editor" if t.get("editor_required") else "offline"
        print(f"  {t['id']:<12} {t['title'][:46]:<48}{t['estimate_days']:>4}d  "
              f"[{kind}]  {gate}")
    if days > 12:
        print(f"\n{C['ylw']}This queue is the project's throughput ceiling (risk R8). "
              f"If it grows two weeks running, the project needs a second human.{C['off']}")
    return 0


def cmd_waves(tasks):
    by_id = index(tasks)
    remaining = {t["id"] for t in tasks if t["status"] not in ("done", "cut")}
    settled = {t["id"] for t in tasks if t["status"] == "done"}
    wave = 0
    while remaining:
        wave += 1
        batch = [i for i in remaining
                 if all(d in settled or d not in by_id for d in (by_id[i].get("depends_on") or []))]
        if not batch:
            print(f"{C['red']}cycle or unsatisfiable dependency among: "
                  f"{sorted(remaining)}{C['off']}")
            return 1
        days = sum(float(by_id[i].get("estimate_days") or 0) for i in batch)
        crit = max((float(by_id[i].get("estimate_days") or 0) for i in batch), default=0)
        print(f"\n{C['bold']}WAVE {wave}{C['off']}  {len(batch)} tasks · {days:.1f} ideal days · "
              f"{C['dim']}critical path {crit:.1f}d if fully parallel{C['off']}")
        for i in sorted(batch, key=lambda x: (by_id[x].get("discipline") or [""])[0]):
            t = by_id[i]
            ed = f" {C['blu']}[editor]{C['off']}" if t.get("editor_required") else ""
            disc = ",".join(t.get("discipline") or [])
            print(f"  {t['id']:<12} {t['title'][:50]:<52}{C['dim']}{disc:<10}"
                  f"{t['estimate_days']}d{C['off']}{ed}")
        if len(batch) > 6:
            print(f"  {C['ylw']}note: cap concurrent in-flight tasks at ~6 "
                  f"(review capacity){C['off']}")
        settled |= set(batch)
        remaining -= set(batch)
    return 0


def cmd_critical(tasks, target=None):
    """Longest dependency chain by estimate days — what actually sets the schedule."""
    by_id = index(tasks)
    memo: dict[str, tuple[float, list[str]]] = {}

    def longest(tid):
        if tid in memo:
            return memo[tid]
        t = by_id.get(tid)
        if not t:
            return (0.0, [])
        best = (0.0, [])
        for d in t.get("depends_on") or []:
            cand = longest(d)
            if cand[0] > best[0]:
                best = cand
        est = float(t.get("estimate_days") or 0)
        memo[tid] = (best[0] + est, best[1] + [tid])
        return memo[tid]

    targets = [target] if target else [t["id"] for t in tasks]
    best = max((longest(x) for x in targets), key=lambda r: r[0])
    days, path = best
    print(f"{C['bold']}Critical path: {days:.1f} ideal days, {len(path)} tasks{C['off']}")
    if not target:
        print(f"{C['dim']}(longest chain in the whole graph){C['off']}")
    acc = 0.0
    for tid in path:
        t = by_id[tid]
        acc += float(t.get("estimate_days") or 0)
        mark = f" {C['ylw']}<- start this early{C['off']}" if float(
            t.get("estimate_days") or 0) >= 3 else ""
        print(f"  {acc:>6.1f}d  {tid:<12} {t['title'][:48]:<50}"
              f"{C['dim']}{t['estimate_days']}d{C['off']}{mark}")
    return 0


def cmd_editor(tasks):
    q = [t for t in tasks if t.get("editor_required") and t["status"] not in ("done", "cut")]
    if not q:
        print("editor queue is empty")
        return 0
    days = sum(float(t.get("estimate_days") or 0) for t in q)
    print(f"{C['bold']}{len(q)} task(s) need a human at an editor · "
          f"{days:.1f} ideal days{C['off']}\n")
    for t in sorted(q, key=lambda x: x["id"]):
        print(f"  {t['id']:<12} {t['title'][:56]:<58}{t['estimate_days']}d  [{t['status']}]")
    if len(q) > 6:
        print(f"\n{C['ylw']}editor queue is growing — this is risk R8. "
              f"See docs/04-production/risks.md{C['off']}")
    return 0


def cmd_stale(tasks):
    bad = [t for t in tasks
           if t["status"] == "in_progress" and not t["_sections"].get("outcome")
           and not t["_sections"].get("plan")]
    for t in bad:
        print(f"{t['id']:<12} {t['title'][:50]:<52} assignee={t.get('assignee')}")
    if not bad:
        print("no stale tasks")
    return 0


def cmd_graph(tasks):
    print("```mermaid\ngraph LR")
    marks = {"done": ":::done", "blocked": ":::blocked", "in_progress": ":::wip"}
    for t in tasks:
        print(f'  {t["id"].replace("-", "_")}["{t["id"]}"]{marks.get(t["status"], "")}')
        for d in t.get("depends_on") or []:
            print(f'  {d.replace("-", "_")} --> {t["id"].replace("-", "_")}')
    print("  classDef done fill:#2d5a2d,color:#fff")
    print("  classDef blocked fill:#7a2020,color:#fff")
    print("  classDef wip fill:#7a6020,color:#fff")
    print("```")
    return 0


def cmd_new(argv):
    if len(argv) < 2:
        print("usage: tasks.py new ID \"Title\"")
        return 1
    tid, title = argv[0], argv[1]
    path = os.path.join(TASK_DIR, f"{tid}.md")
    if os.path.exists(path):
        print(f"{path} already exists")
        return 1
    tpl = open(os.path.join(TASK_DIR, "TASK-TEMPLATE.md"), encoding="utf-8").read()
    tpl = tpl.replace("AREA-NNN", tid).replace("<one line, under 70 chars>", title)
    open(path, "w", encoding="utf-8").write(tpl)
    print(f"created {path} (status: draft — complete it before claiming)")
    return 0


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "board"
    if cmd == "new":
        return cmd_new(sys.argv[2:])
    tasks = load()
    if cmd == "critical":
        return cmd_critical(tasks, sys.argv[2] if len(sys.argv) > 2 else None)
    return {
        "validate": cmd_validate, "board": cmd_board, "ready": cmd_ready,
        "waves": cmd_waves, "editor": cmd_editor, "human": cmd_human,
        "stale": cmd_stale, "graph": cmd_graph,
    }.get(cmd, lambda _: (print(__doc__), 1)[1])(tasks)


if __name__ == "__main__":
    sys.exit(main())
