#!/bin/bash
cd "$(dirname "$0")/.."
#set -x

FORMAT='%-27s %-24s %-35s %9s %8s\n'

describe_version() {
  local version

  version="$(git describe --tags --long --always --dirty 2>/dev/null || true)"
  if test "x$version" = x; then
    version="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  if test "x$version" = x; then
    version="unknown"
  fi

  printf '%s' "$version"
}

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

ROOT_TAG="$(describe_version)"

printf "$FORMAT" "module" "tag" "branch" "worktrees" "branches"
printf "$FORMAT" "." "$ROOT_TAG" "$ROOT_BRANCH" "$(count_worktrees)" "$(count_branches)"

git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | while read DIR; do
  (
    cd "$DIR"
    TAG="$(describe_version)"
    BRANCH="$(
      git branch \
       | grep -E '^\*' \
       | sed -re 's/^\* *//' \
       | tr -d '\n'
    )"

    printf "$FORMAT" "$DIR" "$TAG" "$BRANCH" "$(count_worktrees)" "$(count_branches)"
  ); 
done
