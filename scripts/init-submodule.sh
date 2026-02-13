#!/bin/bash
cd "$(dirname "$0")/.."
set -e
set -x
NAME=$1

if test "x$NAME" = x; then
  exit 2
fi

./scripts/add-submodule.sh "$NAME"
cp -a ./bus-accounts/LICENSE "./$NAME/LICENSE"
cp -a ./bus-accounts/.cursor "./$NAME/.cursor"
cp -a ./bus-accounts/.gitignore "./$NAME/.gitignore"
#cp -a ./bus-accounts/scripts "./$NAME/scripts"
cp -a ./bus-accounts/Makefile "./$NAME/Makefile"
rm "./$NAME/.cursor/rules/bus-accounts.mdc"
touch "./$NAME/.cursor/rules/$NAME.mdc"
