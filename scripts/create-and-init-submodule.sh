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

commit_repo_changes() {
  REPO_DIR="$1"
  COMMIT_MESSAGE="$2"
  SHOULD_PUSH="$3"
  shift 3

  (
    cd "$REPO_DIR"
    git add -A "$@"
    if git diff --cached --quiet -- "$@"; then
      echo "no changes to commit in $REPO_DIR"
    else
      git commit -m "$COMMIT_MESSAGE" -- "$@"
      if test "$SHOULD_PUSH" = "push"; then
        git push -u origin HEAD
      fi
    fi
  )
}

./scripts/create-submodule.sh "$NAME"
sleep 3
./scripts/create-submodule-feature-issue.sh "$NAME"
sleep 3
./scripts/init-submodule-golang.sh "$NAME"
git config -f .gitmodules "submodule.$NAME.branch" develop

commit_repo_changes "$NAME" "chore: initialize module skeleton" push .
commit_repo_changes docs "docs: add $NAME module stub" push "docs/modules/$NAME.md"
commit_repo_changes sdd "sdd: add $NAME module stub" push "docs/modules/$NAME.md"
commit_repo_changes . "chore: add $NAME submodule" "" .gitmodules "$NAME" docs sdd
