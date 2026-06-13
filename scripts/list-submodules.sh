#!/bin/bash
cd "$(dirname "$0")/.."
#set -x

FORMAT='%-27s %-19s %-35s %9s %8s\n'

count_worktrees() {
  git worktree list --porcelain \
    | awk '
      /^worktree / {
        if (seen && !prunable && branch != "refs/heads/develop" && branch != "refs/heads/main") {
          count++
        }
        seen = 1
        branch = ""
        prunable = 0
        next
      }
      /^branch / {
        branch = $2
        next
      }
      /^prunable / {
        prunable = 1
        next
      }
      END {
        if (seen && !prunable && branch != "refs/heads/develop" && branch != "refs/heads/main") {
          count++
        }
        print count + 0
      }
    '
}

count_branches() {
  git for-each-ref --format='%(refname:short)' refs/heads \
    | grep -Ev '^(develop|main)$' \
    | wc -l \
    | tr -d ' '
}

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

printf "$FORMAT" "module" "tag" "branch" "worktrees" "branches"
printf "$FORMAT" "." "$ROOT_TAG" "$ROOT_BRANCH" "$(count_worktrees)" "$(count_branches)"

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

    printf "$FORMAT" "$DIR" "$TAG" "$BRANCH" "$(count_worktrees)" "$(count_branches)"
  ); 
done
