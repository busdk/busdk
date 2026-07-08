#!/bin/bash
cd "$(dirname "$0")/.."
set -e
set -x
NAME=$1

if test "x$NAME" = x; then
  exit 2
fi

if test -d "$NAME"; then
  exit 4
fi

./scripts/create-submodule.sh "$NAME"
sleep 3
./scripts/create-submodule-feature-issue.sh "$NAME"
sleep 3
./scripts/init-submodule-golang.sh "$NAME"

(
  cd "$NAME"
  git add -A
  if git diff --cached --quiet; then
    echo "no skeleton changes to commit in $NAME"
  else
    git commit -m "chore: initialize module skeleton"
    git push -u origin HEAD
  fi
)
