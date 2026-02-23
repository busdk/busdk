#!/bin/sh
set -e

for dir in bus-*; do
  mkdir -p "$dir/.bus/dev"
  cp bus/.bus/dev/{e2e-audit,e2e-refactor,optimize}.txt "$dir/.bus/dev/"
  (
    cd "$dir"
    if git check-ignore -q .bus/dev || git check-ignore -q .bus; then
      echo "warning: $dir/.bus/dev is ignored; skipping git add" >&2
    else
      git add .bus/dev
    fi
  )
done
