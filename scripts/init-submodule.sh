#!/bin/bash
cd "$(dirname "$0")/.."
set -e
set -x
NAME=$1

if test "x$NAME" = x; then
  exit 2
fi

SHORT_NAME="$NAME"
if [ "${SHORT_NAME#bus-}" != "$SHORT_NAME" ]; then
  SHORT_NAME="${SHORT_NAME#bus-}"
fi

#./scripts/create-submodule.sh "$NAME"
#./scripts/create-submodule-feature-issue.sh "$NAME"
./scripts/add-submodule.sh "$NAME"
cp -a ./bus-accounts/LICENSE.md "./$NAME/LICENSE.md"
cp -a ./bus-accounts/AGENTS.md "./$NAME/AGENTS.md"
cp -a ./bus-accounts/.gitignore "./$NAME/.gitignore"
cp -a ./bus-accounts/.bus "./$NAME/.bus"
cp -a ./bus-accounts/Makefile "./$NAME/Makefile"
cp -a ./bus-accounts/Makefile.local "./$NAME/Makefile.local"

touch "./docs/docs/sdd/$NAME.md"
touch "./docs/docs/modules/$NAME.md"
