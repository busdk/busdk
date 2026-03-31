#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
set -euo pipefail
#set -x

TOPIC="${1:-}"

if [ -z "$TOPIC" ]; then
  echo "Usage: ./scripts/remove-worktree.sh <topic>" >&2
  exit 1
fi

REPO_ROOT="$(pwd -P)"
WORKTREE_PATH="$REPO_ROOT/work/$TOPIC"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: Not inside a git work tree: $REPO_ROOT" >&2
  exit 1
}

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "Error: Worktree does not exist: $WORKTREE_PATH" >&2
  exit 1
fi

if [ -f "$WORKTREE_PATH/.gitmodules" ]; then
  git config -f "$WORKTREE_PATH/.gitmodules" --get-regexp '^submodule\..*\.path$' | while read -r _ SUB_PATH; do
    CANONICAL_REPO="$REPO_ROOT/$SUB_PATH"
    SUBMODULE_WORKTREE_PATH="$WORKTREE_PATH/$SUB_PATH"

    if [ ! -d "$CANONICAL_REPO" ]; then
      continue
    fi

    if ! git -C "$CANONICAL_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      continue
    fi

    if git -C "$CANONICAL_REPO" worktree list --porcelain | grep -Fx "worktree $SUBMODULE_WORKTREE_PATH" >/dev/null 2>&1; then
      git -C "$CANONICAL_REPO" worktree remove "$SUBMODULE_WORKTREE_PATH"
      git -C "$CANONICAL_REPO" worktree prune
    fi
  done
fi

git worktree remove --force "$WORKTREE_PATH"
git worktree prune
