#!/bin/sh
set -eu

# Find packages inside each bus/bus-* module that are not reachable from
# current non-wasm CLI main packages in that module.
#
# Default output format (tab-separated):
# ROOT\t<module-dir>\t<main-import-path>
# SUMMARY\t<module-dir>\t<roots-count>\t<unused-count>
# UNUSED\t<module-dir>\t<package-import-path>\t<outside-ref-count>
#
# With --classify-outside, UNUSED lines include two extra fields:
# UNUSED\t<module-dir>\t<package-import-path>\t<outside-ref-count>\t<classification>\t<importer-modules>
# classification:
# - used-by-other-module-cli
# - likely-dead-in-repo

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

CLASSIFY_OUTSIDE=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/find-unreachable-cli-packages.sh [--classify-outside]

Options:
  --classify-outside  Classify each UNUSED package by whether it is reachable
                      from other modules' non-wasm CLI dependency closures.
  -h, --help          Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --classify-outside)
      CLASSIFY_OUTSIDE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

find_modules() {
  find . -maxdepth 1 -type d \( -name 'bus' -o -name 'bus-*' \) | sed 's#^\./##' | sort
}

list_modules_with_go_mod() {
  for mod in $(find_modules); do
    [ -f "$mod/go.mod" ] || continue
    printf '%s\n' "$mod"
  done
}

count_outside_refs() {
  pkg_path=$1
  mod_dir=$2
  refs=$(rg -n --glob '*.go' "\"$pkg_path\"" bus bus-* 2>/dev/null || true)
  if [ -z "$refs" ]; then
    printf '0\n'
    return 0
  fi
  printf '%s\n' "$refs" | awk -F: -v mod="$mod_dir/" '$1 !~ ("^" mod) { c++ } END { print c + 0 }'
}

collect_non_wasm_roots() {
  mod=$1
  out_file=$2
  (
    cd "$mod"
    go list -e -f '{{.ImportPath}}|{{.Name}}' ./... | sed '/^\s*$/d' | \
      awk -F '|' '$2=="main" { print $1 }' | \
      grep -Ev '(^|/)wasm($|/)|-wasm$' | sort -u > "$out_file" || true
  )
}

collect_root_deps() {
  mod=$1
  roots_file=$2
  deps_file=$3
  if [ ! -s "$roots_file" ]; then
    : > "$deps_file"
    return 0
  fi
  (
    cd "$mod"
    xargs go list -e -deps -f '{{.ImportPath}}' < "$roots_file" | sed '/^\s*$/d' | sort -u > "$deps_file"
  )
}

importer_modules_for_pkg() {
  pkg=$1
  owner_mod=$2
  deps_cache_dir=$3
  modules_file=$4

  found=""
  while IFS= read -r omod; do
    [ -n "$omod" ] || continue
    [ "$omod" = "$owner_mod" ] && continue
    dep_file="$deps_cache_dir/$omod.deps"
    [ -f "$dep_file" ] || continue
    if grep -Fxq "$pkg" "$dep_file"; then
      if [ -z "$found" ]; then
        found="$omod"
      else
        found="$found,$omod"
      fi
    fi
  done < "$modules_file"

  printf '%s\n' "$found"
}

MODULES_FILE=$(mktemp)
CACHE_DIR=""
cleanup() {
  rm -f "$MODULES_FILE"
  if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
  fi
}
trap cleanup EXIT INT TERM

list_modules_with_go_mod > "$MODULES_FILE"

if [ "$CLASSIFY_OUTSIDE" -eq 1 ]; then
  CACHE_DIR=$(mktemp -d)
  while IFS= read -r mod; do
    [ -n "$mod" ] || continue
    roots_file="$CACHE_DIR/$mod.roots"
    deps_file="$CACHE_DIR/$mod.deps"
    collect_non_wasm_roots "$mod" "$roots_file"
    collect_root_deps "$mod" "$roots_file" "$deps_file"
  done < "$MODULES_FILE"
fi

while IFS= read -r mod; do
  [ -n "$mod" ] || continue

  all_file=$(mktemp)
  roots_file=$(mktemp)
  deps_file=$(mktemp)
  all_mod_pkgs=$(mktemp)
  unused_file=$(mktemp)

  (
    cd "$mod"
    mod_path=$(go list -e -m -f '{{.Path}}')
    go list -e -f '{{.ImportPath}}|{{.Name}}' ./... | sed '/^\s*$/d' > "$all_file"

    awk -F '|' '$2=="main" { print $1 }' "$all_file" | \
      grep -Ev '(^|/)wasm($|/)|-wasm$' | sort -u > "$roots_file" || true

    if [ ! -s "$roots_file" ]; then
      printf 'SUMMARY\t%s\t0\t0\n' "$mod"
      rm -f "$all_file" "$roots_file" "$deps_file" "$all_mod_pkgs" "$unused_file"
      exit 0
    fi

    while IFS= read -r root_pkg; do
      [ -n "$root_pkg" ] || continue
      printf 'ROOT\t%s\t%s\n' "$mod" "$root_pkg"
    done < "$roots_file"

    xargs go list -e -deps -f '{{.ImportPath}}' < "$roots_file" | sed '/^\s*$/d' | sort -u > "$deps_file"

    awk -F '|' -v prefix="$mod_path" '$1 ~ ("^" prefix "($|/)") { print $1 }' "$all_file" | sort -u > "$all_mod_pkgs"

    comm -23 "$all_mod_pkgs" "$deps_file" > "$unused_file" || true

    roots_count=$(wc -l < "$roots_file" | tr -d ' ')
    unused_count=$(wc -l < "$unused_file" | tr -d ' ')
    printf 'SUMMARY\t%s\t%s\t%s\n' "$mod" "$roots_count" "$unused_count"

    if [ -s "$unused_file" ]; then
      while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        outside_refs=$(count_outside_refs "$pkg" "$mod")
        if [ "$CLASSIFY_OUTSIDE" -eq 1 ]; then
          importers=$(importer_modules_for_pkg "$pkg" "$mod" "$CACHE_DIR" "$MODULES_FILE")
          class="likely-dead-in-repo"
          if [ -n "$importers" ]; then
            class="used-by-other-module-cli"
          else
            importers="-"
          fi
          printf 'UNUSED\t%s\t%s\t%s\t%s\t%s\n' "$mod" "$pkg" "$outside_refs" "$class" "$importers"
        else
          printf 'UNUSED\t%s\t%s\t%s\n' "$mod" "$pkg" "$outside_refs"
        fi
      done < "$unused_file"
    fi
  )

  rm -f "$all_file" "$roots_file" "$deps_file" "$all_mod_pkgs" "$unused_file"
done < "$MODULES_FILE"
