#!/usr/bin/env python3
"""Audit Bus UI/GX downstream adopters and app UI surfaces.

The audit is intentionally deterministic and read-only. It derives the module
set from checked-out `go.mod` files, then reports production UI files and
forbidden old `pkg/uikit` usage so GX/UI adoption can be checked without a
manual repository-wide search.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any


UI_DEPS = (
    "github.com/busdk/bus-ui",
    "github.com/busdk/bus-gx",
)
FORBIDDEN_UIKIT_IMPORT = '"github.com/busdk/bus-ui/pkg/uikit"'
FORBIDDEN_UIKIT_SYMBOL_RE = re.compile(r"\buikit\.[A-Z_][A-Za-z0-9_]*")
GO_IMPORT_RE = re.compile(r'"(github\.com/busdk/(?:bus-ui|bus-gx)(?:/[^"]*)?)"')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="BusDK root to audit (default: current directory)",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="output format (default: text)",
    )
    parser.add_argument(
        "--show-files",
        action="store_true",
        help="print file lists in text output",
    )
    parser.add_argument(
        "--fail-on-forbidden-uikit",
        action="store_true",
        help="exit non-zero when production files import pkg/uikit or call uikit.*",
    )
    return parser.parse_args()


def should_skip(path: Path) -> bool:
    return any(part in {".git", ".bus", "vendor"} for part in path.parts)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def rel(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def go_mod_dependency_text(path: Path) -> str:
    text = read_text(path)
    return "\n".join(line for line in text.splitlines() if not line.startswith("module "))


def direct_ui_deps(go_mod: Path) -> list[str]:
    text = go_mod_dependency_text(go_mod)
    return [dep for dep in UI_DEPS if dep in text]


def collect_go_files(module_dir: Path, tests: bool = False) -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(module_dir):
        current = Path(dirpath)
        dirnames[:] = [name for name in dirnames if name not in {".git", ".bus", "vendor"}]
        if should_skip(current):
            continue
        for filename in filenames:
            if not filename.endswith(".go"):
                continue
            if filename.endswith("_test.go") != tests:
                continue
            path = current / filename
            if should_skip(path):
                continue
            out.append(path)
    return sorted(out)


def is_app_ui_file(module_dir: Path, path: Path) -> bool:
    parts = path.relative_to(module_dir).parts
    joined = "/".join(parts)
    if "/internal/ui/" in f"/{joined}" or joined.startswith("internal/ui/"):
        return True
    if "/internal/serve/" in f"/{joined}" or joined.startswith("internal/serve/"):
        return True
    if "/internal/server/" in f"/{joined}" or joined.startswith("internal/server/"):
        return True
    if "/wasm/" in f"/{joined}" or joined.endswith("_wasm.go"):
        return True
    if joined.startswith("cmd/") and ("/wasm/" in f"/{joined}" or "-wasm/" in joined):
        return True
    return False


def import_matches(text: str) -> list[str]:
    return sorted(set(match.group(1) for match in GO_IMPORT_RE.finditer(text)))


def has_forbidden_uikit(text: str) -> bool:
    return FORBIDDEN_UIKIT_IMPORT in text or FORBIDDEN_UIKIT_SYMBOL_RE.search(text) is not None


def audit_module(root: Path, module_dir: Path) -> dict[str, Any]:
    go_mod = module_dir / "go.mod"
    deps = direct_ui_deps(go_mod)
    production_files = collect_go_files(module_dir, tests=False)
    ui_surface_files: list[str] = []
    ui_import_files: list[str] = []
    forbidden_uikit_files: list[str] = []
    local_ui_candidate_files: list[str] = []
    imports_by_file: dict[str, list[str]] = {}

    for path in production_files:
        text = read_text(path)
        matches = import_matches(text)
        if matches:
            ui_import_files.append(rel(root, path))
            imports_by_file[rel(root, path)] = matches
        if has_forbidden_uikit(text):
            forbidden_uikit_files.append(rel(root, path))
        if is_app_ui_file(module_dir, path):
            ui_surface_files.append(rel(root, path))
            if not matches:
                local_ui_candidate_files.append(rel(root, path))

    return {
        "module": module_dir.name,
        "path": rel(root, module_dir),
        "direct_deps": deps,
        "ui_surface_file_count": len(ui_surface_files),
        "ui_import_file_count": len(ui_import_files),
        "forbidden_uikit_file_count": len(forbidden_uikit_files),
        "local_ui_candidate_file_count": len(local_ui_candidate_files),
        "ui_surface_files": ui_surface_files,
        "ui_import_files": ui_import_files,
        "forbidden_uikit_files": forbidden_uikit_files,
        "local_ui_candidate_files": local_ui_candidate_files,
        "imports_by_file": imports_by_file,
    }


def audit(root: Path) -> dict[str, Any]:
    modules: list[dict[str, Any]] = []
    for go_mod in sorted(root.glob("*/go.mod")):
        if should_skip(go_mod):
            continue
        module_dir = go_mod.parent
        deps = direct_ui_deps(go_mod)
        if module_dir.name != "bus-ui" and not deps:
            continue
        modules.append(audit_module(root, module_dir))

    forbidden_total = sum(item["forbidden_uikit_file_count"] for item in modules)
    ui_surface_total = sum(item["ui_surface_file_count"] for item in modules)
    local_candidate_total = sum(item["local_ui_candidate_file_count"] for item in modules)
    return {
        "schema_version": "busdk.gx_ui_adopter_audit/v1",
        "root": str(root),
        "module_count": len(modules),
        "ui_surface_file_count": ui_surface_total,
        "local_ui_candidate_file_count": local_candidate_total,
        "forbidden_uikit_file_count": forbidden_total,
        "modules": modules,
    }


def print_text(result: dict[str, Any], show_files: bool) -> None:
    print("# GX/UI downstream adopter audit")
    print(f"root: {result['root']}")
    print(f"modules: {result['module_count']}")
    print(f"ui surface files: {result['ui_surface_file_count']}")
    print(f"local ui candidate files: {result['local_ui_candidate_file_count']}")
    print(f"forbidden uikit files: {result['forbidden_uikit_file_count']}")
    print()
    for module in result["modules"]:
        dep_text = ", ".join(module["direct_deps"]) if module["direct_deps"] else "(core module)"
        print(f"{module['path']}:")
        print(f"  deps: {dep_text}")
        print(f"  ui surface files: {module['ui_surface_file_count']}")
        print(f"  ui import files: {module['ui_import_file_count']}")
        print(f"  local ui candidates: {module['local_ui_candidate_file_count']}")
        print(f"  forbidden uikit files: {module['forbidden_uikit_file_count']}")
        if show_files:
            for key in (
                "ui_surface_files",
                "ui_import_files",
                "local_ui_candidate_files",
                "forbidden_uikit_files",
            ):
                if not module[key]:
                    continue
                print(f"  {key}:")
                for path in module[key]:
                    print(f"    {path}")
        print()


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    result = audit(root)
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_text(result, args.show_files)
    if args.fail_on_forbidden_uikit and result["forbidden_uikit_file_count"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
