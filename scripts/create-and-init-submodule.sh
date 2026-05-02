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
./scripts/init-submodule.sh "$NAME"
