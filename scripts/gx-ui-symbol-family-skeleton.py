#!/usr/bin/env python3
"""Prepare a GX/UI symbol-family move from pkg/uikit to pkg/ui.

This is a deliberately small temporary helper. It only handles the repeated
mechanical part of the current GX/UI refactor:

- copy explicitly listed source files to explicitly listed target files;
- rewrite `package uikit` to the requested target package;
- find or remove alias lines whose left-hand symbol is explicitly listed.

It defaults to dry-run. Human or worker review still owns compile errors,
behavior tests, and API-shape decisions.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CopySpec:
    source: Path
    target: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="module root")
    parser.add_argument(
        "--copy",
        action="append",
        default=[],
        metavar="SRC:DST",
        help="copy SRC to DST, rewriting the package declaration",
    )
    parser.add_argument(
        "--target-package",
        default="ui",
        help="target package name for copied Go files",
    )
    parser.add_argument(
        "--alias-file",
        action="append",
        default=[],
        type=Path,
        help="facade file to scan for removable uikit alias lines",
    )
    parser.add_argument(
        "--symbols",
        default="",
        help="comma-separated left-hand alias symbols to remove or report",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write copied files and remove matching alias lines",
    )
    return parser.parse_args()


def parse_copy_specs(values: list[str]) -> list[CopySpec]:
    specs: list[CopySpec] = []
    for value in values:
        if ":" not in value:
            raise SystemExit(f"--copy must be SRC:DST, got {value!r}")
        source, target = value.split(":", 1)
        specs.append(CopySpec(Path(source), Path(target)))
    return specs


def rewrite_package(text: str, target_package: str) -> str:
    return re.sub(r"(?m)^package\s+uikit\b", f"package {target_package}", text, count=1)


def alias_line_re(symbols: set[str]) -> re.Pattern[str]:
    names = "|".join(re.escape(symbol) for symbol in sorted(symbols, key=len, reverse=True))
    return re.compile(rf"^(\s*)({names})\s*=\s*uikit\.[A-Za-z0-9_]+(?:\[.*\])?\s*$")


def process_alias_file(path: Path, symbols: set[str], apply: bool) -> list[str]:
    if not symbols:
        return []
    pattern = alias_line_re(symbols)
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    removed: list[str] = []
    kept: list[str] = []
    for line in lines:
        if pattern.match(line.rstrip("\n")):
            removed.append(line.rstrip("\n"))
            continue
        kept.append(line)
    if apply and removed:
        path.write_text("".join(kept), encoding="utf-8")
    return removed


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    copy_specs = parse_copy_specs(args.copy)
    symbols = {symbol.strip() for symbol in args.symbols.split(",") if symbol.strip()}

    print("# GX/UI symbol-family skeleton")
    print(f"root: {root}")
    print(f"mode: {'apply' if args.apply else 'dry-run'}")
    print()

    for spec in copy_specs:
        source = root / spec.source
        target = root / spec.target
        text = source.read_text(encoding="utf-8")
        rewritten = rewrite_package(text, args.target_package)
        print(f"copy: {spec.source} -> {spec.target}")
        if args.apply:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(rewritten, encoding="utf-8")

    if copy_specs:
        print()

    for alias_path in args.alias_file:
        path = root / alias_path
        removed = process_alias_file(path, symbols, args.apply)
        print(f"alias-file: {alias_path}")
        if removed:
            for line in removed:
                print(f"  remove: {line.strip()}")
        else:
            print("  remove: <none>")

    if not args.apply:
        print()
        print("dry-run only; rerun with --apply to write files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
