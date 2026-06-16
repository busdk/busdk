#!/usr/bin/env python3
"""Compact GX/UI uikit surface inventory.

This is intentionally a small, temporary supervisor aid. It does not rewrite
files or run builds; it emits bounded counts and file lists for the GX/UI goal
document so repeated inventory refreshes do not burn worker or model turns.
"""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path


UI_DEPS = (
    "github.com/busdk/bus-ui",
    "github.com/busdk/bus-gx",
)
UIKIT_IMPORT = '"github.com/busdk/bus-ui/pkg/uikit"'
UIKIT_SYMBOL_RE = re.compile(r"\buikit\.[A-Z_][A-Za-z0-9_]*")
UIKIT_DOC_RE = re.compile(r"github\.com/busdk/bus-ui/pkg/uikit|\buikit\.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="BusDK root to audit (default: current directory)",
    )
    parser.add_argument(
        "--show-files",
        action="store_true",
        help="print matching files under each count",
    )
    return parser.parse_args()


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    return ".bus" in parts or "vendor" in parts or ".git" in parts


def is_under(path: Path, *parts: str) -> bool:
    joined = "/".join(path.parts)
    return any(part in joined for part in parts)


def module_name(root: Path, path: Path) -> str:
    rel = path.relative_to(root)
    return rel.parts[0] if rel.parts else "."


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def has_uikit_surface(text: str) -> bool:
    return UIKIT_IMPORT in text or UIKIT_SYMBOL_RE.search(text) is not None


def go_mod_users(root: Path) -> list[Path]:
    users: list[Path] = []
    for go_mod in sorted(root.glob("*/go.mod")):
        if should_skip(go_mod):
            continue
        text = read_text(go_mod)
        dependency_text = "\n".join(
            line for line in text.splitlines() if not line.startswith("module ")
        )
        if go_mod.parent.name == "bus-ui" or any(dep in dependency_text for dep in UI_DEPS):
            users.append(go_mod.parent)
    return users


def collect_files(root: Path, suffix: str) -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        current = Path(dirpath)
        dirnames[:] = [
            name
            for name in dirnames
            if name not in {".git", ".bus", "vendor"}
        ]
        if should_skip(current):
            continue
        for filename in filenames:
            if filename.endswith(suffix):
                out.append(current / filename)
    return sorted(out)


def matching_go_files(root: Path, tests: bool) -> list[Path]:
    matches: list[Path] = []
    for path in collect_files(root, ".go"):
        if path.name.endswith("_test.go") != tests:
            continue
        rel = path.relative_to(root)
        rel_s = "/".join(rel.parts)
        if "/pkg/uikit/" in f"/{rel_s}" or "/examples/" in f"/{rel_s}":
            continue
        text = read_text(path)
        if has_uikit_surface(text):
            matches.append(path)
    return matches


def matching_docs(root: Path) -> list[Path]:
    matches: list[Path] = []
    for path in collect_files(root, ".md"):
        rel_s = "/".join(path.relative_to(root).parts)
        if "/.bus/" in f"/{rel_s}":
            continue
        text = read_text(path)
        if UIKIT_DOC_RE.search(text):
            matches.append(path)
    return matches


def owner_facades(root: Path) -> list[Path]:
    pkg = root / "bus-ui" / "pkg"
    if not pkg.exists():
        return []
    matches: list[Path] = []
    for path in collect_files(pkg, ".go"):
        if path.name.endswith("_test.go"):
            continue
        rel_s = "/".join(path.relative_to(root).parts)
        if "/pkg/uikit/" in f"/{rel_s}":
            continue
        text = read_text(path)
        if has_uikit_surface(text):
            matches.append(path)
    return matches


def group_by_module(root: Path, files: list[Path]) -> dict[str, list[Path]]:
    grouped: dict[str, list[Path]] = {}
    for path in files:
        grouped.setdefault(module_name(root, path), []).append(path)
    return dict(sorted(grouped.items()))


def print_paths(root: Path, paths: list[Path], indent: str = "  ") -> None:
    for path in paths:
        print(f"{indent}{path.relative_to(root)}")


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    users = go_mod_users(root)
    prod = matching_go_files(root, tests=False)
    tests = matching_go_files(root, tests=True)
    docs = matching_docs(root)
    owner = owner_facades(root)
    prod_by_module = group_by_module(root, prod)

    print("# GX/UI uikit inventory audit")
    print(f"root: {root}")
    print()
    print(f"dependency modules: {len(users)}")
    for path in users:
        print(f"  {path.relative_to(root)}")
    print()
    print(f"owner facade production files: {len(owner)}")
    if args.show_files:
        print_paths(root, owner)
    print()
    print(f"production adopter/core files: {len(prod)}")
    for mod, paths in prod_by_module.items():
        print(f"  {mod}: {len(paths)}")
        if args.show_files:
            print_paths(root, paths, indent="    ")
    print()
    print(f"test files: {len(tests)}")
    if args.show_files:
        print_paths(root, tests)
    print()
    print(f"markdown files: {len(docs)}")
    if args.show_files:
        print_paths(root, docs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
