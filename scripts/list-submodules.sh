#!/bin/bash
cd "$(dirname "$0")/.."
#set -x

FORMAT='%-17s %-9s %s\n'

ROOT_BRANCH="$(
    git branch \
     | grep -E '^\*' \
     | sed -re 's/^\* *//' \
     | tr -d '\n'
)"

ROOT_TAG=$((git describe --tags 2>/dev/null)|sort -n|tail -n1)
if test "x$ROOT_TAG" = x; then
  ROOT_TAG="$(git rev-parse --short HEAD)"
fi

printf "$FORMAT" "." "$ROOT_TAG" "$ROOT_BRANCH"

cat .gitmodules |grep -F path|awk '{print $3}'|while read DIR; do  
  (
    cd $DIR
    TAG=$((git describe --tags 2>/dev/null)|sort -n|tail -n1)
    if test "x$TAG" = x; then
      TAG="$(git rev-parse --short HEAD)"
    fi
    BRANCH="$(
      git branch \
       | grep -E '^\*' \
       | sed -re 's/^\* *//' \
       | tr -d '\n'
    )"

    printf "$FORMAT" "$DIR" "$TAG" "$BRANCH"
  ); 
done
