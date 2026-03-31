#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
set -euo pipefail
#set -x

TOPIC="${1:-}"

if [ -z "$TOPIC" ]; then
  echo "Usage: source ./scripts/init-worktree.sh <topic>" >&2
  return 1 2>/dev/null || exit 1
fi

REPO_ROOT="$(pwd -P)"
WORK_ROOT="$REPO_ROOT/work"
WORKTREE_PATH="$WORK_ROOT/$TOPIC"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: Not inside a git work tree: $REPO_ROOT" >&2
  return 1 2>/dev/null || exit 1
}

mkdir -p "$WORK_ROOT"

if [ -e "$WORKTREE_PATH" ]; then
  echo "Worktree already exists: $WORKTREE_PATH" >&2
  cd "$WORKTREE_PATH"
  return 0 2>/dev/null || exit 0
fi

git worktree add --detach "$WORKTREE_PATH" HEAD

PIDS=""
FAILED=0

if [ -f "$WORKTREE_PATH/.gitmodules" ]; then
  git config -f "$WORKTREE_PATH/.gitmodules" --get-regexp '^submodule\..*\.path$' | while read -r _ SUB_PATH; do
    (
      CANONICAL_REPO="$REPO_ROOT/$SUB_PATH"
      SUBMODULE_WORKTREE_PATH="$WORKTREE_PATH/$SUB_PATH"
      GITLINK_COMMIT="$(git -C "$WORKTREE_PATH" rev-parse "HEAD:$SUB_PATH")"

      git -C "$CANONICAL_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        echo "Error: Canonical submodule repo not found or not a git repo: $CANONICAL_REPO" >&2
        exit 1
      }

      mkdir -p "$(dirname "$SUBMODULE_WORKTREE_PATH")"

      if [ -e "$SUBMODULE_WORKTREE_PATH" ]; then
        if [ ! -d "$SUBMODULE_WORKTREE_PATH" ]; then
          echo "Error: Submodule target exists and is not a directory: $SUBMODULE_WORKTREE_PATH" >&2
          exit 1
        fi

        ENTRIES="$(find "$SUBMODULE_WORKTREE_PATH" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort)"
        COUNT="$(printf '%s\n' "$ENTRIES" | sed '/^$/d' | wc -l | tr -d ' ')"

        if [ "$COUNT" = "0" ]; then
          rmdir "$SUBMODULE_WORKTREE_PATH"
        elif [ "$COUNT" = "1" ] && [ "$ENTRIES" = ".git" ] && [ -f "$SUBMODULE_WORKTREE_PATH/.git" ]; then
          rm "$SUBMODULE_WORKTREE_PATH/.git"
          rmdir "$SUBMODULE_WORKTREE_PATH" || {
            echo "Error: Directory not empty after removing .git: $SUBMODULE_WORKTREE_PATH" >&2
            exit 1
          }
        else
          echo "Error: Refusing to continue: unexpected contents in $SUBMODULE_WORKTREE_PATH" >&2
          echo "Found entries:" >&2
          printf '%s\n' "$ENTRIES" | sed '/^$/d' | sed 's/^/  /' >&2
          exit 1
        fi
      fi

      git -C "$CANONICAL_REPO" worktree add --detach "$SUBMODULE_WORKTREE_PATH" "$GITLINK_COMMIT"
    ) &
    PIDS="$PIDS $!"
  done

  for PID in $PIDS; do
    if ! wait "$PID"; then
      FAILED=1
    fi
  done

  if [ "$FAILED" != "0" ]; then
    echo "Error: One or more submodule worktree initializations failed" >&2
    return 1 2>/dev/null || exit 1
  fi
fi

cd "$WORKTREE_PATH"
return 0 2>/dev/null || exit 0
