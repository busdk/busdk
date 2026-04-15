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

ORIGINAL_ARGC=$#

hash_file_sha256() {
  local file="${1:?missing file}"
  if command -v shasum >/dev/null 2>&1; then
    if shasum -a 256 "$file" | awk '{print substr($1, 1, 12)}'; then
      return
    fi
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    if sha256sum "$file" | awk '{print substr($1, 1, 12)}'; then
      return
    fi
  fi
  echo "start-shell: missing shasum/sha256sum for image tag hashing" >&2
  exit 1
}

REPO_ROOT="$(pwd -P)"
WORKTREE_PATH="$REPO_ROOT/work/$TOPIC"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
HOST_HOME="${HOME:-}"
WORK_HOME="$WORKTREE_PATH/.home"
IMAGE_HASH="$(hash_file_sha256 containers/agent/Dockerfile)"
IMAGE_NAME="agent:${IMAGE_HASH}"

./scripts/init-worktree.sh "$TOPIC"

mkdir -p \
  "$WORK_HOME" \
  "$WORK_HOME/.cache" \
  "$WORK_HOME/.cache/go-build" \
  "$WORK_HOME/go/pkg/mod" \
  "$WORK_HOME/.config"

cat >"$WORK_HOME/.bashrc" <<EOF
export PROMPT_DIRTRIM=3
PS1='[busdk:\h \W]\\$ '
EOF

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  docker build --pull -t "$IMAGE_NAME" -f containers/agent/Dockerfile .
fi

if [ "$#" -eq 0 ]; then
  set -- bash
fi

DOCKER_RUN_ARGS=(
  --rm
  --hostname "$TOPIC"
  --user "$USER_ID:$GROUP_ID"
  -e HOME="$WORK_HOME"
  -e USER=agent
  -e LOGNAME=agent
  -e XDG_CACHE_HOME="$WORK_HOME/.cache"
  -e GOPATH="$WORK_HOME/go"
  -e GOCACHE="$WORK_HOME/.cache/go-build"
  -e GOMODCACHE="$WORK_HOME/go/pkg/mod"
  -v "$REPO_ROOT:$REPO_ROOT:ro"
  -v "$WORKTREE_PATH:$WORKTREE_PATH:rw"
  -w "$WORKTREE_PATH"
)

if [ "$ORIGINAL_ARGC" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then
  DOCKER_RUN_ARGS=(-it "${DOCKER_RUN_ARGS[@]}")
fi

if [ -n "$HOST_HOME" ] && [ -d "$HOST_HOME/.codex" ]; then
  mkdir -p "$WORK_HOME/.codex"
  DOCKER_RUN_ARGS+=(-v "$HOST_HOME/.codex:$WORK_HOME/.codex:rw")
fi

if [ -n "$HOST_HOME" ] && [ -f "$HOST_HOME/.gitconfig" ]; then
  DOCKER_RUN_ARGS+=(-v "$HOST_HOME/.gitconfig:$WORK_HOME/.gitconfig:ro")
fi

exec docker run "${DOCKER_RUN_ARGS[@]}" "$IMAGE_NAME" "$@"
