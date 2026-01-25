#!/bin/bash
cd "$(dirname "$0")/.."
set -e
set -x

NAME="$1"

if test "x$NAME" = x; then
  echo 'USAGE: ./scripts/add-submodule.sh NAME' >&2
  exit 1
fi

ORG='busdk'
BRANCH='main'
DIR="$NAME"
REPO_NAME="$ORG/$NAME"
REPO_URL="git@github.com:$REPO_NAME.git"

if test -d "$DIR"; then
  git config -f .gitmodules "submodule.$DIR.path" "$DIR"
  git config -f .gitmodules "submodule.$DIR.url" "$REPO_URL"
else
  git submodule add "$REPO_URL" "$DIR"
fi
git config -f .gitmodules "submodule.$DIR.branch" "$BRANCH"
