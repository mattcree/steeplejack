#!/usr/bin/env python3
"""Enforce the conventions that agents will otherwise break silently.

See docs/06-workflow/04-enforced-conventions.md. Every check here exists because
the alternative is a sentence in a document that nobody re-reads.

The sim purity rules (1-3) are not style: SteeplejackSim must compile standalone
under CMake with no Unreal installed, because that is what keeps the gameplay
layer testable in 20 seconds and editable by agents. See ADR-0004.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(ROOT, "Source", "SteeplejackSim")
SIM_EXTS = (".h", ".cpp", ".hpp", ".inl")

errors: list[str] = []

# --- rule 1-3: sim/ purity ---------------------------------------------------
# Rules 1-3. SteeplejackSim must build standalone under CMake with no Unreal present
# (ADR-0004). Every pattern here would break that.
FORBIDDEN_IN_SIM = [
    (r"#include\s+[\"<](Core|Engine|GameFramework|UObject|CoreMinimal|Kismet|Chaos|Niagara)",
     "SteeplejackSim must not include Unreal headers — it builds standalone (ADR-0004)"),
    (r"\b(FVector|FVector2D|FRotator|FTransform|FString|FName|FText|TArray|TMap|TSet|"
     r"TSharedPtr|TWeakObjectPtr|UObject|AActor|UClass|UPROPERTY|UFUNCTION|UCLASS|USTRUCT|"
     r"FMath|UE_LOG|GEngine|GWorld|FQuat|TObjectPtr)\b",
     "SteeplejackSim must not use Unreal types — use sj::Vec3, std::vector, std::string, <cmath>"),
    (r"\.generated\.h", "SteeplejackSim must not use the UE reflection system"),
    (r"\brand\s*\(|\bsrand\s*\(|std::random_device|std::mt19937",
     "SteeplejackSim must not use ambient RNG — take a seeded sj::Rng& parameter"),
    (r"\bstd::chrono\b|\btime\s*\(|\bclock\s*\(",
     "SteeplejackSim must not read a clock — time is an explicit float dt parameter"),
    (r"\bstd::cout\b|\bprintf\s*\(|\bstd::cerr\b",
     "SteeplejackSim must not write to stdout — return values, don't log"),
    (r"\bstatic\s+(?!const|constexpr|inline\s+constexpr)[A-Za-z_][\w:<>]*\s+\w+\s*(=|;)",
     "SteeplejackSim must not hold mutable static state — it breaks determinism and replay"),
]

# --- rule 4: no magic numbers in sim/ ----------------------------------------
ALLOWED_LITERALS = {"0", "1", "-1", "2", "0.0", "1.0", "0.5", "100.0", "2.0", "-1.0",
                    "0f", "1f", "0.0f", "1.0f", "0.5f", "2.0f", "-1.0f", "100.0f",
                    "8", "16", "32", "64", "17"}   # widths, and C++17
# C++ float literals carry an f/F suffix; integer literals may carry u/l/z.
NUM = re.compile(r"(?<![\w.])(-?\d+\.?\d*)(?:[fFuUlLzZ]+)?(?![\w.])")


def check_sim_purity():
    if not os.path.isdir(SIM):
        return
    for dirpath, _, files in os.walk(SIM):
        for fn in files:
            if not fn.endswith(SIM_EXTS):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
            for i, line in enumerate(open(os.path.join(dirpath, fn), encoding="utf-8"), 1):
                code = line.split("//")[0]
                for pat, msg in FORBIDDEN_IN_SIM:
                    if re.search(pat, code):
                        errors.append(f"{rel}:{i}: {msg}")
                # magic numbers
                if "// literal:" in line:
                    continue
                if re.match(r"\s*(constexpr|const\s|#define|static_assert|enum|template)", code):
                    continue
                if "#include" in code:
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
                        f"or annotate the line with '// literal: <reason>' "
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
            if os.path.splitext(fn)[1] not in {".h", ".cpp", ".hpp", ".inl", ".cs", ".md",
                                               ".json", ".txt", ".yml", ".yaml", ".usf",
                                               ".ush", ".uproject", ".ini", ".py", ""}:
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

    ref = re.compile(r'\.Get[FIB]\(\s*"([^"]+)"')
    for dirpath, _, files in os.walk(SIM):
        for fn in files:
            if not fn.endswith(SIM_EXTS):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
            for i, line in enumerate(open(os.path.join(dirpath, fn), encoding="utf-8"), 1):
                for m in ref.finditer(line.split("//")[0]):
                    snake = m.group(1).split(".")[-1]
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
