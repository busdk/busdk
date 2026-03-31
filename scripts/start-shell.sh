#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
set -euo pipefail
#set -x

TOPIC="${1:-}"
shift || true

if [ -z "$TOPIC" ]; then
  echo "Usage: ./scripts/start-shell.sh <topic> [command...]" >&2
  exit 1
fi

REPO_ROOT="$(pwd -P)"
WORKTREE_PATH="$REPO_ROOT/work/$TOPIC"
IMAGE_NAME="agent"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

./scripts/init-worktree.sh "$TOPIC"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  docker build -t "$IMAGE_NAME" -f containers/agent/Dockerfile .
fi

if [ "$#" -eq 0 ]; then
  set -- bash
fi

docker run --rm -it \
  --hostname "$TOPIC" \
  --user "$USER_ID:$GROUP_ID" \
  -e HOME="$WORKTREE_PATH/.home" \
  -e USER=agent \
  -e LOGNAME=agent \
  -e PS1='[\h \W]\$ ' \
  -v "$REPO_ROOT:$REPO_ROOT:ro" \
  -v "$WORKTREE_PATH:$WORKTREE_PATH:rw" \
  -w "$WORKTREE_PATH" \
  "$IMAGE_NAME" \
  "$@"
