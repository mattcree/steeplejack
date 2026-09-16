#!/usr/bin/env python3
"""PreToolUse guard: block the git commands that destroy work irrecoverably.

Two classes of loss, and only one of them is recoverable:

  1. ORPHANED COMMITS  — force-push, branch delete, hard reset past a commit.
     Recoverable from reflog, but the reflog is LOCAL, is empty in a fresh clone,
     and is garbage-collected in ~30 days. On a worktree that has been removed it
     may not exist at all.

  2. DESTROYED UNCOMMITTED EDITS — reset --hard, checkout ., restore, clean -fd,
     stash drop, worktree remove. **The reflog cannot recover these. Ever.**

This hook blocks both classes and tells the agent the safe alternative. It is
deliberately conservative: a false block costs ten seconds, a false allow can cost
a day. Agents are told in AGENTS.md that being blocked here means "commit first",
not "find a way around it".

Wired in .claude/settings.json as a PreToolUse hook on Bash.
Exit 0 = allow, exit 2 = block (stderr is shown to the model).
"""
from __future__ import annotations

import json
import re
import sys

# (pattern, why it is blocked, what to do instead)
BLOCKED: list[tuple[str, str, str]] = [
    (r"\bgit\s+push\b.*(--force(?!-with-lease)\b|\s-f\b)",
     "force-push orphans commits on the remote; anyone who pulled loses their reference to them",
     "If you genuinely must rewrite a pushed branch, use --force-with-lease, and only on a branch "
     "you own that nobody has based work on."),

    (r"\bgit\s+reset\s+(--hard|--merge|--keep)\b",
     "reset --hard DESTROYS uncommitted changes. The reflog cannot recover them",
     "Commit first (`make wip`), then reset. Or `git stash -u` if you truly want them parked. "
     "To undo a commit while keeping the work: `git reset --soft HEAD~1`."),

    (r"\bgit\s+checkout\s+(--\s+)?\.(\s|$)|\bgit\s+checkout\s+--\s+\S",
     "checkout -- <path> DESTROYS uncommitted changes to those files, unrecoverably",
     "Commit first (`make wip`). If you want to see the committed version, "
     "`git show HEAD:<path>`."),

    (r"\bgit\s+clean\b.*-[a-zA-Z]*[fdx]",
     "clean -fd DELETES untracked files, including any new file you have written but not added",
     "`git clean -n` to see what it would delete. Commit or add what you want to keep first."),

    (r"\bgit\s+worktree\s+remove\b",
     "worktree remove can take an unmerged branch AND uncommitted edits with no warning — "
     "this is one of the most common ways agent work is lost",
     "Use `make wt-drop ID=<TASK-ID>`, which refuses unless the branch is merged and pushed, "
     "and takes a backup ref either way."),

    (r"\bgit\s+branch\s+(-D|--delete\s+--force)\b",
     "branch -D deletes a branch even if it is unmerged, orphaning every commit on it",
     "`git branch -d` (lowercase) refuses to delete unmerged work, which is the point. "
     "If the work is genuinely dead, push it first so it exists somewhere other than this disk."),

    (r"\bgit\s+stash\s+(drop|clear)\b",
     "stash drop/clear discards stashed work with no reflog entry you can easily find",
     "Leave it. A stale stash costs nothing. If you must, `git stash branch <name>` turns it "
     "into a real branch first."),

    (r"\bgit\s+rebase\b(?!.*--abort|.*--continue|.*--skip)",
     "rebasing rewrites history; on a pushed branch it orphans the old commits",
     "`make land ID=<TASK-ID>` rebases safely: it takes a backup ref, rebases, runs the full "
     "gate, and only then merges. Do not rebase by hand."),

    (r"\bgit\s+push\b.*\b(main|master)\b|\bgit\s+push\s+origin\s+HEAD:main\b",
     "agents never push to main; integration is serialized through the merge queue",
     "Push your task branch, set the task to `status: review`, and the integrator runs "
     "`make land ID=<TASK-ID>`."),

    (r"\brm\s+-rf?\s+.*\.git(\s|/|$)",
     "deleting .git destroys every commit, branch and reflog entry on this disk",
     "There is no legitimate reason for an agent to do this."),
]

# Allowed even though they match a blocked pattern above.
EXEMPT = [
    r"\bgit\s+stash\s+branch\b",
    r"\bgit\s+clean\s+-n\b",
    r"--dry-run\b",
]


def restore_is_destructive(cmd: str) -> bool:
    """`git restore --staged <path>` only unstages and is safe.

    Anything else — plain restore, or --worktree — overwrites the working tree from
    the index or a commit, and the reflog cannot bring those edits back.
    """
    if not re.search(r"\bgit\s+restore\b", cmd):
        return False
    has_staged = "--staged" in cmd or re.search(r"\s-S\b", cmd)
    has_worktree = "--worktree" in cmd or re.search(r"\s-W\b", cmd)
    return has_worktree or not has_staged


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    if payload.get("tool_name") != "Bash":
        return 0
    cmd = (payload.get("tool_input") or {}).get("command", "")
    if not cmd:
        return 0

    for pat in EXEMPT:
        if re.search(pat, cmd):
            return 0

    if restore_is_destructive(cmd):
        print(
            f"BLOCKED by .claude/hooks/git_guard.py\n\n"
            f"  Command: {cmd.strip()[:200]}\n\n"
            f"  Why: `git restore` overwrites the working tree. The reflog cannot recover "
            f"uncommitted edits.\n\n"
            f"  Instead: commit first (`make wip`), then restore. "
            f"`git restore --staged <path>` alone is fine — it only unstages.\n\n"
            f"  See docs/06-workflow/07-integration.md.",
            file=sys.stderr,
        )
        return 2

    for pat, why, instead in BLOCKED:
        if re.search(pat, cmd):
            print(
                f"BLOCKED by .claude/hooks/git_guard.py\n\n"
                f"  Command: {cmd.strip()[:200]}\n\n"
                f"  Why: {why}.\n\n"
                f"  Instead: {instead}\n\n"
                f"  This guard is conservative on purpose. Being blocked here means "
                f"'commit your work first', not 'find another way to run this'. "
                f"See docs/06-workflow/07-integration.md.",
                file=sys.stderr,
            )
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
