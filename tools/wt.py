#!/usr/bin/env python3
"""Worktree lifecycle and the serialized merge queue.

The integration model, in one line: **parallel generation, sequential merging.**

Agents generate in isolated worktrees, all at once. Work integrates through `land`,
one task at a time, each fully verified before the next starts. That is the 2026
state of the art for multi-agent development and it is what stops "six green PRs
that do not work together".

WHERE A TASK'S STATUS LIVES — the trunk carries the claim, the BRANCH carries the
handoff, and **the branch is authoritative**. `start` commits `status: in_progress`
to the trunk so two agents cannot claim the same task; the worktree branch is cut
from origin/TRUNK *before* that commit, so a handoff (`status: review`) can only be
written on the branch. `land` and `status` therefore read status from the branch via
`task_field_on`, falling back to the trunk when there is no branch copy. Reading it
from the trunk instead — which is what this tool did originally — meant `land` never
saw a handoff and refused every task as 'in_progress'. Nothing could merge at all.

Every command here is built around two failure modes that cost real work:

  LOST WORK   `git worktree remove` will take an unmerged branch and uncommitted
              edits with no warning. The reflog is local, is empty in a fresh
              clone, and cannot recover uncommitted edits at all. So: every branch
              is pushed the moment it exists, every risky operation takes a backup
              ref first, and `drop` refuses rather than asks.

  CONFLICTS   Prevented upstream by task `owns:` globs, not resolved downstream.
              `land` rebases one branch at a time onto a main that is always green,
              so a conflict is between one branch and a known-good trunk — never
              between six branches at once.

    wt.py start <ID>    create an isolated worktree, claim the task, push the branch
    wt.py save [msg]    WIP commit + push. The panic button. Run it constantly.
    wt.py status        every worktree, and exactly what is not yet safe
    wt.py land <ID>     the merge queue: backup, rebase, verify, merge, push
    wt.py drop <ID>     remove a worktree, refusing if anything would be lost
    wt.py doctor        find work that exists only on this disk
"""
from __future__ import annotations

import datetime
import os
import re
import subprocess
import sys

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                      text=True).stdout.strip() or os.getcwd()
TASKS = os.path.join(ROOT, "tasks")
LOCK = os.path.join(ROOT, ".git", "steeplejack-land.lock")
TRUNK = "main"

C = {"red": "\033[31m", "grn": "\033[32m", "ylw": "\033[33m", "blu": "\033[34m",
     "dim": "\033[2m", "bold": "\033[1m", "off": "\033[0m"}
if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    C = {k: "" for k in C}


def git(*args, cwd=None, check=True, quiet=False):
    r = subprocess.run(["git", *args], cwd=cwd or ROOT, capture_output=True, text=True)
    if check and r.returncode:
        if not quiet:
            print(f"{C['red']}git {' '.join(args)}{C['off']}\n{r.stderr.strip()}")
        raise SystemExit(1)
    return r.stdout.strip()


def die(msg: str, *extra: str) -> None:
    print(f"{C['red']}error{C['off']} {msg}")
    for e in extra:
        print(f"        {e}")
    raise SystemExit(1)


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:28].rstrip("-")


def task_path(tid: str) -> str:
    p = os.path.join(TASKS, f"{tid}.md")
    if not os.path.exists(p):
        die(f"no such task: {tid}", "`make ready` lists what you can claim.")
    return p


def task_field(tid: str, field: str) -> str:
    for line in open(task_path(tid), encoding="utf-8").read().split("\n---", 1)[0].splitlines():
        if line.startswith(f"{field}:"):
            return line.split(":", 1)[1].strip()
    return ""


def task_field_on(tid: str, field: str, branch: str) -> str:
    """Read a task field from `branch`, falling back to the trunk checkout.

    Status lives on the BRANCH, not on the trunk. `start` writes the claim to the
    trunk so two agents cannot claim the same task, but the branch is cut from
    origin/TRUNK *before* that commit — so the handoff (`status: review`) can only
    ever be written on the branch. Reading status from the trunk means never seeing
    a handoff, which deadlocked `land` completely: every task read back as
    'in_progress' and nothing could ever merge.
    """
    rel = os.path.relpath(task_path(tid), ROOT)
    blob = git("show", f"{branch}:{rel}", check=False, quiet=True)
    if not blob:
        return task_field(tid, field)
    for line in blob.split("\n---", 1)[0].splitlines():
        if line.startswith(f"{field}:"):
            return line.split(":", 1)[1].strip()
    return ""


def set_task_field(tid: str, field: str, value: str) -> None:
    p = task_path(tid)
    s = open(p, encoding="utf-8").read()
    s = re.sub(rf"^{field}:.*$", f"{field}: {value}", s, count=1, flags=re.M)
    open(p, "w", encoding="utf-8").write(s)


def branch_for(tid: str) -> str:
    return f"{tid.lower()}-{slug(task_field(tid, 'title'))}"


def worktree_for(tid: str) -> str:
    return os.path.join(os.path.dirname(ROOT), f"sj-{tid.lower()}")


def worktrees() -> list[dict]:
    out, cur = [], {}
    for line in git("worktree", "list", "--porcelain").splitlines():
        if not line:
            if cur:
                out.append(cur)
            cur = {}
        elif line.startswith("worktree "):
            cur["path"] = line[9:]
        elif line.startswith("branch "):
            cur["branch"] = line[7:].replace("refs/heads/", "")
        elif line == "detached":
            cur["branch"] = "(detached)"
    if cur:
        out.append(cur)
    return out


def unsafe(path: str, branch: str) -> list[str]:
    """Everything in this worktree that exists ONLY on this disk."""
    problems = []
    dirty = git("status", "--porcelain", cwd=path, check=False)
    if dirty:
        n = len(dirty.splitlines())
        problems.append(f"{n} uncommitted change(s) — the reflog CANNOT recover these")
    if branch and branch != "(detached)":
        remote = git("ls-remote", "--heads", "origin", branch, check=False, quiet=True)
        if not remote:
            n = git("rev-list", "--count", branch, check=False, quiet=True) or "?"
            problems.append(f"branch '{branch}' has never been pushed ({n} commit(s) local only)")
        else:
            ahead = git("rev-list", "--count", f"origin/{branch}..{branch}",
                        cwd=path, check=False, quiet=True)
            if ahead and ahead != "0":
                problems.append(f"{ahead} commit(s) not pushed")
    return problems


# ---------------------------------------------------------------- commands

def cmd_start(tid: str) -> int:
    status = task_field(tid, "status")
    if status not in ("ready", "draft"):
        die(f"{tid} is '{status}', not claimable.",
            "`make ready` lists what you can claim.")
    if task_field(tid, "human_required") == "true" or \
       task_field(tid, "editor_required") == "true":
        die(f"{tid} needs a human (Unreal editor, a recording, or a room of testers).",
            "`make human-queue` lists these. Agents cannot complete them.")

    wt, br = worktree_for(tid), branch_for(tid)
    if os.path.exists(wt):
        die(f"{wt} already exists.", f"Resume it, or `make wt-drop ID={tid}` first.")

    git("fetch", "origin", TRUNK, quiet=True)

    # Branch from the local trunk, not origin/TRUNK.
    #
    # `new-task` writes the task file into the local working tree and the claim commit also goes to
    # the local trunk, which agents cannot push (the git guard forbids it, deliberately). The trunk
    # only reaches origin when some *other* task lands. So cutting from origin/TRUNK hands the agent
    # a worktree in which its own task file — the one thing it is told to read first — does not
    # exist, silently, until an unrelated merge happens to flush the trunk.
    #
    # `land` already rebases onto the local trunk for the same underlying reason (SETUP-005), so
    # this makes start and land agree about what the trunk is. Branching from local also means the
    # worktree carries every landed task, which is what `make validate` and `make check-links`
    # expect.
    base = TRUNK
    if not git("rev-parse", "--verify", "--quiet", TRUNK, check=False, quiet=True):
        base = f"origin/{TRUNK}"   # fresh clone with no local trunk ref yet

    ahead = git("rev-list", "--count", f"origin/{TRUNK}..{base}", check=False, quiet=True)
    print(f"creating worktree {C['dim']}{wt}{C['off']} on branch {C['bold']}{br}{C['off']}")
    if ahead and ahead != "0":
        print(f"       {C['dim']}from local {TRUNK}, {ahead} commit(s) ahead of origin "
              f"— they land with the next `make land`{C['off']}")
    git("worktree", "add", "-b", br, wt, base)

    # rerere remembers conflict resolutions, so the same conflict is only solved once.
    git("config", "rerere.enabled", "true", cwd=wt)
    git("config", "rerere.autoupdate", "true", cwd=wt)

    set_task_field(tid, "status", "in_progress")
    set_task_field(tid, "assignee", os.environ.get("AGENT_ID", "agent"))
    git("add", task_path(tid))
    git("commit", "-m", f"{tid}: claim", "--only", task_path(tid), cwd=ROOT, check=False)

    # Push immediately. From this moment the branch exists somewhere other than this disk.
    git("push", "-u", "origin", br, cwd=wt)

    print(f"{C['grn']}ready{C['off']}  cd {wt}")
    print(f"       {C['dim']}commit early and often — `make wip` is one command{C['off']}")
    return 0


def cmd_save(msg: str) -> int:
    cwd = os.getcwd()
    if not git("status", "--porcelain", cwd=cwd, check=False):
        print("nothing to save — working tree is clean")
        return 0
    br = git("rev-parse", "--abbrev-ref", "HEAD", cwd=cwd)
    if br in (TRUNK, "HEAD"):
        die(f"refusing to WIP-commit on {br}.", "Work happens on a task branch.")
    git("add", "-A", cwd=cwd)
    git("commit", "-m", msg or "wip", cwd=cwd)
    git("push", "origin", br, cwd=cwd)
    print(f"{C['grn']}saved{C['off']}  {br} pushed — this work now exists off this disk")
    return 0


def cmd_status() -> int:
    wts = [w for w in worktrees() if os.path.abspath(w["path"]) != os.path.abspath(ROOT)]
    if not wts:
        print("no task worktrees")
        return 0
    total_problems = 0
    print(f"{C['bold']}  {'worktree':<20}{'branch':<34}{'task':<30}state{C['off']}")
    for w in wts:
        tid = os.path.basename(w["path"]).replace("sj-", "").upper()
        if os.path.exists(os.path.join(TASKS, f"{tid}.md")):
            st = task_field_on(tid, "status", w.get("branch", "")) or "?"
            trunk_st = task_field(tid, "status")
            if trunk_st != st:
                # The trunk carries the claim, the branch carries the handoff. Showing
                # both makes the split visible instead of silently reporting the stale one.
                st = f"{st} <- {trunk_st} on {TRUNK}"
        else:
            st = "?"
        problems = unsafe(w["path"], w.get("branch", ""))
        total_problems += len(problems)
        mark = f"{C['grn']}safe{C['off']}" if not problems else f"{C['red']}AT RISK{C['off']}"
        br = w.get("branch", "?")
        br = br if len(br) <= 32 else br[:29] + "..."
        st = st if len(st) <= 30 else st[:27] + "..."
        print(f"  {os.path.basename(w['path'])[:19]:<20}{br:<34}{st:<30}{mark}")
        for p in problems:
            print(f"    {C['red']}!{C['off']} {p}")
    if total_problems:
        print(f"\n{C['red']}{total_problems} item(s) exist only on this disk.{C['off']} "
              f"Run `make wip` in each affected worktree.")
    else:
        print(f"\n{C['grn']}All work is pushed. Nothing would be lost if this disk died.{C['off']}")
    return 0


def cmd_land(tid: str) -> int:
    if os.path.exists(LOCK):
        die("another `land` is in progress.",
            "Integration is serialized on purpose — one task merges at a time.",
            f"If that run died, remove {LOCK}")
    open(LOCK, "w").write(str(os.getpid()))
    try:
        return _land(tid)
    finally:
        if os.path.exists(LOCK):
            os.remove(LOCK)


def _land(tid: str) -> int:
    wt, br = worktree_for(tid), branch_for(tid)
    st = task_field_on(tid, "status", br)
    if st != "review":
        die(f"{tid} is '{st}' on {br}, not 'review'.",
            "A task lands only after an implementer handed off AND a reviewer passed it.",
            f"The handoff is written on the branch — check `git show {br}:tasks/{tid}.md`.")

    if not os.path.exists(wt):
        die(f"no worktree at {wt}")
    if git("status", "--porcelain", cwd=wt, check=False):
        die(f"{wt} has uncommitted changes.", "Run `make wip` there first — never lose them here.")

    git("fetch", "origin", quiet=True)

    # Bring the local trunk up to date FIRST, then rebase onto the local trunk — not onto
    # origin/TRUNK. The two are not the same: `start` commits each claim to the local trunk,
    # and the git guard stops agents pushing it, so the local trunk routinely sits ahead of
    # origin. Rebasing onto origin/TRUNK and then fast-forwarding the local one fails with
    # "Not possible to fast-forward" the moment a single claim commit is outstanding.
    git("pull", "--ff-only", "origin", TRUNK, cwd=ROOT, check=False)

    # 1. Backup ref, pushed. If everything below goes wrong, the work is still on origin.
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = f"backup/{tid.lower()}-{ts}"
    git("branch", backup, br, cwd=wt)
    git("push", "origin", backup, cwd=wt)
    print(f"{C['dim']}backup pushed: {backup}{C['off']}")

    # 2. Rebase onto the trunk, with rerere OFF — see below.
    print(f"rebasing {br} onto {TRUNK}...")
    # rerere OFF for the duration of the land. wt-start enables rerere.autoupdate so a human
    # solves a conflict once; but in `land` the task-file conflict is resolved by this tool,
    # every time, and rerere replaying a remembered resolution auto-stages it and leaves zero
    # unmerged paths — which breaks the loop below (nothing to `checkout --theirs`) and makes
    # the outcome depend on what this machine happens to have seen before. A merge queue must
    # do the same thing on every machine.
    r = subprocess.run(["git", "-c", "rerere.enabled=false", "rebase", TRUNK], cwd=wt,
                       capture_output=True, text=True)

    # A task's OWN file conflicts on every single land, by construction: `start` commits
    # `status: in_progress` to the trunk, and the branch writes `status: review` plus its
    # Plan and Outcome to the same file. That is not an ownership violation — it is the
    # claim-on-trunk model meeting the handoff-on-branch model on one line. The branch is
    # authoritative for its own task file (it holds the handoff), so resolve to the branch
    # and carry on. Anything else conflicting is a real violation and still aborts.
    own = os.path.relpath(task_path(tid), ROOT)
    stalled = ""
    for _ in range(50):  # bounded: one stop per conflicting commit, never unbounded
        if not r.returncode:
            break
        conflicted = git("diff", "--name-only", "--diff-filter=U", cwd=wt,
                         check=False).splitlines()
        if not conflicted:
            # A stop with NOTHING unmerged means rerere already staged a resolution for us
            # (wt-start turns on rerere.autoupdate). The loop below cannot use
            # `checkout --theirs` in that state — there is no stage 3 left to take — so the
            # rebase runs with rerere disabled and this should not happen. If it still does,
            # report what git said rather than guessing.
            state = git("status", cwd=wt, check=False, quiet=True)
            if "rebase in progress" in state.lower() and "unmerged" not in state.lower():
                print(f"{C['dim']}  resolution already staged; continuing{C['off']}")
                r = subprocess.run(["git", "-c", "rerere.enabled=false", "rebase", "--continue"],
                                   cwd=wt, capture_output=True, text=True,
                                   env={**os.environ, "GIT_EDITOR": "true"})
                continue
            stalled = ("`git rebase --continue` failed with no conflicted paths.\n"
                       f"        git said: {(r.stderr or r.stdout).strip()[-400:]}")
            break

        if conflicted != [own]:
            break

        # Resolving whole-file loses anything the trunk copy had and the branch's does not.
        # Task files do get edited on main directly, so count what is being dropped rather
        # than dropping it silently.
        base = git("show", f"{TRUNK}:{own}", cwd=wt, check=False, quiet=True)
        head = git("show", f":3:{own}", cwd=wt, check=False, quiet=True)
        # Set membership, not a diff: counts trunk lines whose exact text appears nowhere
        # in the branch's copy. A heads-up, not an accounting — it under-reports a line
        # that merely moved.
        #
        # The claim line and the unfilled template placeholders differ on EVERY task by
        # construction, so counting them would print a warning on every single land and
        # train everyone to ignore it. Excluding them makes zero the normal case, which
        # is what makes a non-zero count worth reading.
        def carries_content(line: str) -> bool:
            s = line.strip()
            return bool(s) and not s.startswith(("status:", "assignee:", "<!--"))

        head_lines = set(head.splitlines())
        lost = len([ln for ln in base.splitlines()
                    if carries_content(ln) and ln not in head_lines])
        note = (f", dropping {lost} line(s) present on {TRUNK} but not on the branch"
                if lost else "")
        print(f"{C['dim']}  {own}: taking the branch's copy (it holds the handoff)"
              f"{note}{C['off']}")

        # Mid-rebase, --theirs is the commit being replayed, i.e. the branch. If that fails
        # the index still holds the trunk's side, and staging it would silently apply the
        # INVERSE resolution — so bail instead of adding.
        co = subprocess.run(["git", "checkout", "--theirs", "--", own], cwd=wt,
                            capture_output=True, text=True)
        if co.returncode:
            stalled = (f"could not take the branch's copy of {own}: "
                       f"{co.stderr.strip() or 'unknown error'}")
            break
        git("add", own, cwd=wt)
        r = subprocess.run(["git", "-c", "rerere.enabled=false", "rebase", "--continue"],
                           cwd=wt, capture_output=True, text=True,
                           env={**os.environ, "GIT_EDITOR": "true"})
    else:
        # Only a stall if the rebase is still failing. Exhausting the loop on a 50th
        # `rebase --continue` that SUCCEEDED is a completed rebase, not a stall, and
        # aborting it here would throw away a good merge at exactly the bound.
        if r.returncode:
            # Careful with the wording: exhausting the loop does not prove the file is still
            # conflicted — the last iteration may have stopped for some other reason.
            stalled = (f"gave up after 50 rebase stops on {own}.\n"
                       f"        git said: {(r.stderr or r.stdout).strip()[-300:]}")

    if stalled:
        subprocess.run(["git", "rebase", "--abort"], cwd=wt, capture_output=True)
        print(f"{C['red']}STOPPED{C['off']} {stalled}")
        print(f"Rebase aborted; your branch is untouched and safe on origin as {backup}.")
        print(f"This is NOT an ownership violation — it is {own}, the task's own file, "
              f"which conflicts on every land by construction.")
        print(f"Resolve by hand in {wt}, `make wip`, then `make land ID={tid}` again.")
        return 1

    if r.returncode:
        conflicted = git("diff", "--name-only", "--diff-filter=U", cwd=wt, check=False)
        subprocess.run(["git", "rebase", "--abort"], cwd=wt, capture_output=True)
        print(f"{C['red']}CONFLICT{C['off']} rebasing {br} onto {TRUNK}. Rebase aborted; "
              f"your branch is untouched.\n")
        print("Conflicted files:")
        for f in conflicted.splitlines():
            print(f"  {f}")
        print(f"\n{C['ylw']}A conflict here means the ownership model was violated.{C['off']}")
        print("Two tasks wrote the same file without a dependency between them, or someone")
        print("worked outside their `owns:` globs. Before resolving:")
        print(f"  1. `python3 tools/tasks.py validate` — does it report an ownership conflict?")
        print(f"  2. Find which task also touched these files, and say so in the PR.")
        print(f"  3. Resolve in {wt}, `make wip`, then `make land ID={tid}` again.")
        print(f"\nYour work is safe on origin as {backup}.")
        return 1

    # 3. Verify the REBASED result, not what the agent tested.
    print(f"verifying rebased result...")
    v = subprocess.run(["make", "ci"], cwd=wt, capture_output=True, text=True)
    if v.returncode:
        print(f"{C['red']}GATE FAILED{C['off']} after rebase. Not merging.\n")
        print(v.stdout[-3000:])
        print(f"\nThe branch passed before the rebase and fails after it, so something on")
        print(f"{TRUNK} interacts with this change. Fix it in {wt}, `make wip`, land again.")
        print(f"Your work is safe on origin as {backup}.")
        return 1

    # 4. Fast-forward only. The trunk is never merged into; it only ever advances.
    git("push", "--force-with-lease", "origin", br, cwd=wt)
    git("checkout", TRUNK, cwd=ROOT)
    git("merge", "--ff-only", br, cwd=ROOT)
    git("push", "origin", TRUNK, cwd=ROOT)

    set_task_field(tid, "status", "done")
    git("add", task_path(tid), cwd=ROOT)
    git("commit", "-m", f"{tid}: done", "--only", task_path(tid), cwd=ROOT, check=False)
    git("push", "origin", TRUNK, cwd=ROOT, check=False)

    print(f"{C['grn']}landed{C['off']}  {tid} is on {TRUNK} and marked done")
    print(f"        {C['dim']}make wt-drop ID={tid}   # when you are finished with the worktree{C['off']}")
    return 0


def cmd_drop(tid: str, force: bool = False) -> int:
    wt, br = worktree_for(tid), branch_for(tid)
    if not os.path.exists(wt):
        print(f"no worktree at {wt} — nothing to drop")
        return 0

    problems = unsafe(wt, br)
    git("fetch", "origin", TRUNK, quiet=True)
    merged = git("branch", "--contains", br, "--list", TRUNK, check=False, quiet=True) or \
        git("rev-list", "--count", f"origin/{TRUNK}..{br}", cwd=wt, check=False, quiet=True) == "0"
    if not merged:
        problems.append(f"branch '{br}' is not merged into {TRUNK}")

    if problems and not force:
        print(f"{C['red']}REFUSING to drop {wt}{C['off']}\n")
        for p in problems:
            print(f"  ! {p}")
        print(f"\n`git worktree remove` would take all of this with no warning. That is one of")
        print(f"the most common ways agent work is lost.\n")
        print(f"  To keep it:  cd {wt} && make wip")
        print(f"  To land it:  make land ID={tid}")
        print(f"  To discard:  make wt-drop ID={tid} FORCE=1   "
              f"{C['dim']}(takes a pushed backup first){C['off']}")
        return 1

    if problems:
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = f"backup/{tid.lower()}-dropped-{ts}"
        git("add", "-A", cwd=wt, check=False)
        git("commit", "-m", f"{tid}: WIP at forced drop", cwd=wt, check=False)
        git("branch", backup, br, cwd=wt, check=False)
        git("push", "origin", backup, cwd=wt, check=False)
        print(f"{C['ylw']}forced{C['off']} — backed up to origin as {backup}")

    subprocess.run(["git", "worktree", "remove", "--force", wt], cwd=ROOT, check=False)
    git("worktree", "prune", check=False)
    print(f"dropped {wt}")
    return 0


def cmd_doctor() -> int:
    print(f"{C['bold']}Work that exists only on this disk{C['off']}\n")
    findings = 0

    for w in worktrees():
        if os.path.abspath(w["path"]) == os.path.abspath(ROOT):
            continue
        for p in unsafe(w["path"], w.get("branch", "")):
            print(f"  {C['red']}!{C['off']} {os.path.basename(w['path'])}: {p}")
            findings += 1

    git("fetch", "origin", quiet=True, check=False)
    for br in git("branch", "--format=%(refname:short)").splitlines():
        if br in (TRUNK,) or br.startswith("backup/"):
            continue
        if not git("ls-remote", "--heads", "origin", br, check=False, quiet=True):
            print(f"  {C['red']}!{C['off']} branch '{br}' has never been pushed")
            findings += 1

    stale = [w for w in worktrees()
             if os.path.abspath(w["path"]) != os.path.abspath(ROOT)
             and not os.path.exists(w["path"])]
    for w in stale:
        print(f"  {C['ylw']}~{C['off']} stale worktree registration: {w['path']} "
              f"(run `git worktree prune`)")
        findings += 1

    backups = [b for b in git("branch", "-r", "--format=%(refname:short)").splitlines()
               if "/backup/" in b]
    print(f"\n{C['dim']}{len(backups)} backup ref(s) on origin. "
          f"These are your safety net; delete them only when you are sure.{C['off']}")

    if not findings:
        print(f"  {C['grn']}Nothing at risk. Every commit exists on origin.{C['off']}")
    else:
        print(f"\n{findings} finding(s). Run `make wip` in each affected worktree.")
    return 1 if findings else 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cmd, args = sys.argv[1], sys.argv[2:]

    def need_id(cmd_name: str, make_target: str) -> str:
        if not args:
            die(f"`{cmd_name}` needs a task ID.",
                f"e.g. make {make_target} ID=CORE-003",
                "`make ready` lists what you can claim; `make board` shows everything.")
        return args[0].upper()

    if cmd == "start":
        return cmd_start(need_id("start", "wt-start"))
    if cmd == "save":
        return cmd_save(" ".join(args))
    if cmd == "status":
        return cmd_status()
    if cmd == "land":
        return cmd_land(need_id("land", "land"))
    if cmd == "drop":
        return cmd_drop(need_id("drop", "wt-drop"), force=os.environ.get("FORCE") == "1")
    if cmd == "doctor":
        return cmd_doctor()
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
