#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  printf '%s\n' "usage: scripts/commit-plan-only.sh <repo-path> <commit-message>" >&2
  exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$script_dir/commit-tracker-only.sh" "$1" "$2" PLAN.md
