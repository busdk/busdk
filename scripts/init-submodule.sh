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
cp -a ./bus-accounts/LICENSE "./$NAME/LICENSE"
cp -a ./bus-accounts/.cursor "./$NAME/.cursor"
cp -a ./bus-accounts/.gitignore "./$NAME/.gitignore"
cp -a ./bus-accounts/.bus "./$NAME/.bus"
cp -a ./bus-accounts/Makefile "./$NAME/Makefile"

cat > "./$NAME/.bus/dev/test.sh" <<EOF
#!/bin/sh
set -e
make test
./tests/e2e_bus_${SHORT_NAME}.sh
EOF

chmod +x "./$NAME/.bus/dev/test.sh"

touch "./docs/docs/sdd/$NAME.md"
touch "./docs/docs/modules/$NAME.md"

