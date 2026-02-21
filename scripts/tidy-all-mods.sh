#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

mods=$(find . -maxdepth 1 -type d \( -name 'bus' -o -name 'bus-*' \) | sed 's#^\./##' | sort)
for mod in $mods; do
  [ -f "$mod/go.mod" ] || continue
  printf '==> go mod tidy %s\n' "$mod"
  (cd "$mod" && go mod tidy)
done
