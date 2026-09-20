#!/usr/bin/env python3
"""The binary-asset gate — CORE-010.

Binary is the half of this project agents cannot author or review, which is why the foley is
synthesised from JSON and the character is built by a Blender script. What binary there is goes
through Git LFS, and this is what stops that arrangement rotting.

Four checks, in the order they are likely to fail:

1. **Coverage.** A binary file whose extension is not declared in `.gitattributes` is stored raw in
   the object database, forever, in every clone anyone ever makes. This is the one that fires: the
   character `.glb` sat outside LFS for a day because nobody added the extension when the Blender
   pipeline landed.
2. **Integrity.** A file that *is* declared but is stored as its own bytes rather than as a pointer.
   That happens when files are committed before the pattern is added, or by someone whose clone has
   no `git lfs install`. It is invisible until a clone gets slow, and it needs history rewriting to
   fix, so it is worth a gate.
3. **Per file.** Anything over `MAX_FILE_MB` is a conversation, not a commit.
4. **Total.** The whole repository's binary weight, warning before it fails.

Not a linter for asset quality. It only asks whether a binary thing is where binary things go.

    python3 tools/check_content_size.py          # the gate
    python3 tools/check_content_size.py --list   # what it can see, largest first
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The cap is not 25 GB. That number came from ADR-0004 and a photoreal Unreal build with Megascans;
# this is a grey-box Godot game whose audio is synthesised from envelopes and whose one character is
# 236 KB built by a script. A cap two hundred times the current size is not a gate, it is a comment.
#
# 2 GB is where a fresh clone stops being something you do without thinking about it, which is the
# thing actually worth protecting. Revisit it when there is an art pipeline to revisit it for.
MAX_TOTAL_MB = 2048
WARN_TOTAL_MB = 1536
MAX_FILE_MB = 25

# Extensions that are binary and must therefore be declared in .gitattributes. Deliberately a
# denylist of what we know is binary rather than a guess at what is text: a new text format should
# not need a change here, and a new binary one should be a deliberate decision.
BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".tga", ".exr", ".hdr", ".psd", ".tif", ".tiff", ".bmp", ".webp",
    ".wav", ".ogg", ".mp3", ".flac", ".aiff",
    ".fbx", ".glb", ".blend", ".obj", ".dae", ".usd", ".usdz",
    ".ttf", ".otf", ".woff", ".woff2",
    ".mp4", ".mov", ".webm",
    ".zip", ".7z", ".tar", ".gz", ".bz2", ".xz",
    ".res", ".scn", ".ctex", ".pck", ".so", ".dll", ".dylib", ".a", ".lib",
}

# Built, not committed. `.so` matches a binary extension but `godot/bin/` is build output that
# `.gitignore` keeps out; if one is ever tracked, the coverage check will say so.
SKIP_PREFIXES = ("build/", ".deps/", "third_party/")

RED = "\033[31m"
YELLOW = "\033[33m"
DIM = "\033[2m"
OFF = "\033[0m"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=False
    ).stdout


def tracked_files() -> list[str]:
    return [f for f in git("ls-files", "-z").split("\0") if f and not f.startswith(SKIP_PREFIXES)]


def lfs_patterns() -> set[str]:
    """The extensions `.gitattributes` sends through LFS."""
    out: set[str] = set()
    attrs = ROOT / ".gitattributes"
    if not attrs.exists():
        return out
    for line in attrs.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "filter=lfs" not in line:
            continue
        pattern = line.split()[0]
        if pattern.startswith("*."):
            out.add(pattern[1:].lower())
    return out


POINTER_MAGIC = b"version https://git-lfs.github.com/spec/"


def real_size(path: Path) -> int:
    """How big the file really is, whether or not LFS has smudged it.

    CI checks out with `lfs: false`, so every tracked binary is a 130-byte pointer there. Taking
    `st_size` would have this gate report 3 KB of assets on every CI run and never fire — a gate
    that cannot fail, which is the thing this project keeps finding and removing. A pointer carries
    the real size on a `size` line, so read that.
    """
    if not path.exists():
        return 0
    size = path.stat().st_size
    if size > 1024:   # a pointer is a few hundred bytes at most
        return size
    try:
        head = path.read_bytes()
    except OSError:
        return size
    if not head.startswith(POINTER_MAGIC):
        return size
    for line in head.decode("utf-8", "replace").splitlines():
        if line.startswith("size "):
            try:
                return int(line[5:])
            except ValueError:
                return size
    return size


def lfs_pointers() -> set[str]:
    """Files git-lfs is actually storing as pointers, as it reports them."""
    out: set[str] = set()
    for line in git("lfs", "ls-files", "-n").splitlines():
        if line.strip():
            out.add(line.strip())
    return out


def main() -> int:
    listing = "--list" in sys.argv
    declared = lfs_patterns()
    pointers = lfs_pointers()

    if not declared:
        print(f"{RED}error{OFF}  .gitattributes declares no LFS patterns at all")
        return 1

    binaries: list[tuple[int, str]] = []
    uncovered: list[str] = []
    raw: list[str] = []
    oversize: list[tuple[int, str]] = []

    for rel in tracked_files():
        ext = Path(rel).suffix.lower()
        if ext not in BINARY_EXTENSIONS:
            continue
        size = real_size(ROOT / rel)
        binaries.append((size, rel))
        if ext not in declared:
            uncovered.append(rel)
        elif rel not in pointers:
            raw.append(rel)
        if size > MAX_FILE_MB * 1024 * 1024:
            oversize.append((size, rel))

    total = sum(size for size, _ in binaries)
    total_mb = total / (1024 * 1024)

    if listing:
        for size, rel in sorted(binaries, reverse=True):
            mark = "lfs" if rel in pointers else "RAW"
            print(f"  {size / 1024:9.1f} KB  {DIM}{mark}{OFF}  {rel}")
        print(f"\n  {len(binaries)} binary file(s), {total_mb:.1f} MB")
        return 0

    errors = 0

    for rel in uncovered:
        print(
            f"{RED}error{OFF}  {rel}: a {Path(rel).suffix} is binary and '*{Path(rel).suffix}' is "
            f"not declared in .gitattributes, so it is stored raw in every clone forever"
        )
        errors += 1

    for rel in raw:
        print(
            f"{RED}error{OFF}  {rel}: declared for LFS but stored as its own bytes. Committed "
            f"before the pattern was added, or committed without 'git lfs install'."
        )
        errors += 1

    for size, rel in oversize:
        print(
            f"{RED}error{OFF}  {rel}: {size / (1024 * 1024):.1f} MB, over the {MAX_FILE_MB} MB "
            f"per-file cap. A file this size is a conversation, not a commit."
        )
        errors += 1

    if total_mb > MAX_TOTAL_MB:
        print(
            f"{RED}error{OFF}  binary assets total {total_mb:.0f} MB, over the "
            f"{MAX_TOTAL_MB} MB cap"
        )
        errors += 1
    elif total_mb > WARN_TOTAL_MB:
        print(
            f"{YELLOW}warn{OFF}   binary assets total {total_mb:.0f} MB, past the "
            f"{WARN_TOTAL_MB} MB warning line"
        )

    print(
        f"\n{len(binaries)} binary file(s), {total_mb:.1f} MB of {MAX_TOTAL_MB} MB, "
        f"{len(pointers)} through LFS, {errors} error(s)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
