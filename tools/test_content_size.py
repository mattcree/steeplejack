#!/usr/bin/env python3
"""Tests for the binary-asset gate — CORE-010.

A gate with no test is decoration, and a gate that cannot fail is worse than no gate at all: it
reports success forever and everyone stops looking. So each of the four checks gets a fixture that
makes it fire, built in a throwaway git repository with LFS in it.

    python3 tools/test_content_size.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent / "check_content_size.py"

PASSED = 0
FAILED = 0


def check(ok: bool, what: str) -> None:
    global PASSED, FAILED
    if ok:
        PASSED += 1
        print(f"  ok    {what}")
    else:
        FAILED += 1
        print(f"  FAIL  {what}", file=sys.stderr)


def git(repo: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=False)


def make_repo(tmp: Path) -> Path:
    repo = tmp / "repo"
    (repo / "tools").mkdir(parents=True)
    git(repo.parent, "init", "-q", "repo")
    git(repo, "config", "user.email", "t@example.invalid")
    git(repo, "config", "user.name", "T")
    shutil.copy(TOOL, repo / "tools" / TOOL.name)
    return repo


def run(repo: Path, *args: str) -> subprocess.CompletedProcess:
    env = dict(os.environ, TERM="dumb")
    return subprocess.run(
        [sys.executable, "tools/check_content_size.py", *args],
        cwd=repo, capture_output=True, text=True, check=False, env=env,
    )


def main() -> int:
    if shutil.which("git-lfs") is None:
        print("  --    git-lfs is not installed; the gate's integrity check cannot be tested here")

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        # --- no patterns at all is itself an error ---------------------------------------------
        repo = make_repo(tmp / "a")
        (repo / ".gitattributes").write_text("*.md text eol=lf\n")
        git(repo, "add", "-A")
        out = run(repo)
        check(out.returncode != 0, "a .gitattributes with no LFS patterns fails the gate")
        check("declares no LFS patterns" in out.stdout, "and says that is what is wrong")

        # --- an undeclared binary extension ------------------------------------------------------
        repo = make_repo(tmp / "b")
        (repo / ".gitattributes").write_text("*.png filter=lfs diff=lfs merge=lfs -text\n")
        (repo / "model.glb").write_bytes(b"glTF\x02\x00\x00\x00" + b"\0" * 64)
        git(repo, "add", "-A")
        out = run(repo)
        check(out.returncode != 0, "a .glb with no '*.glb' pattern fails the gate")
        check("not declared in .gitattributes" in out.stdout, "and names the missing pattern")
        check("stored raw in every clone" in out.stdout, "and says why that matters")

        # --- declared, but committed as its own bytes --------------------------------------------
        # The failure that is invisible until a clone gets slow: the pattern arrives after the file.
        repo = make_repo(tmp / "c")
        # Pretend LFS is not installed. Without this the *global* filter cleans the file on `git
        # add` and the fixture quietly tests nothing — which is the exact shape of bug this whole
        # file exists to prevent, and it happened here first.
        git(repo, "config", "filter.lfs.process", "")
        git(repo, "config", "filter.lfs.clean", "cat")
        git(repo, "config", "filter.lfs.smudge", "cat")
        git(repo, "config", "filter.lfs.required", "false")
        (repo / ".gitattributes").write_text("*.md text eol=lf\n")
        (repo / "art.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 128)
        git(repo, "add", "-A")
        git(repo, "commit", "-qm", "before the pattern")
        (repo / ".gitattributes").write_text("*.png filter=lfs diff=lfs merge=lfs -text\n")
        git(repo, "add", "-A")
        git(repo, "commit", "-qm", "the pattern, too late")
        out = run(repo)
        check(out.returncode != 0, "a .png declared for LFS but stored raw fails the gate")
        check("stored as its own bytes" in out.stdout, "and says it is not a pointer")

        # --- over the per-file cap ----------------------------------------------------------------
        repo = make_repo(tmp / "d")
        (repo / ".gitattributes").write_text("*.png filter=lfs diff=lfs merge=lfs -text\n")
        (repo / "huge.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * (26 * 1024 * 1024))
        git(repo, "add", "-A")
        out = run(repo)
        check("per-file cap" in out.stdout, "a 26 MB file trips the per-file cap")
        check(out.returncode != 0, "and that fails the gate")

        # --- a clean repository passes -------------------------------------------------------------
        repo = make_repo(tmp / "e")
        (repo / ".gitattributes").write_text("*.png filter=lfs diff=lfs merge=lfs -text\n")
        git(repo, "add", "-A")
        git(repo, "commit", "-qm", "nothing binary yet")
        out = run(repo)
        check(out.returncode == 0, "a repository with no binaries passes")

        # --- a pointer reports the size of the thing it points at --------------------------------
        # CI checks out with `lfs: false`, so everything binary is a 130-byte pointer there. A gate
        # that measured those would report three kilobytes of assets for ever and never fire.
        # The pattern is left off deliberately so no clean filter runs and the pointer text reaches
        # the index as written — this fixture is about measurement, not about coverage.
        repo = make_repo(tmp / "g")
        (repo / ".gitattributes").write_text("*.tga filter=lfs diff=lfs merge=lfs -text\n")
        (repo / "big.png").write_text(
            "version https://git-lfs.github.com/spec/v1\n"
            "oid sha256:" + "0" * 64 + "\n"
            "size 41943040\n"   # 40 MB, well over the per-file cap
        )
        git(repo, "add", "-A")
        out = run(repo, "--list")
        check("40960.0 KB" in out.stdout,
            "an unsmudged pointer is measured at the size it points at, not 130 bytes")

        # --- --list says what it can see ----------------------------------------------------------
        repo = make_repo(tmp / "f")
        (repo / ".gitattributes").write_text("*.png filter=lfs diff=lfs merge=lfs -text\n")
        (repo / "a.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 32)
        git(repo, "add", "-A")
        out = run(repo, "--list")
        check(out.returncode == 0 and "a.png" in out.stdout, "--list names the files it found")

    print(f"\n{PASSED} passed, {FAILED} failed")
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
