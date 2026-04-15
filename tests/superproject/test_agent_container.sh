#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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
  echo "missing shasum/sha256sum for agent-container selftest" >&2
  exit 1
}

TEST_REPO="$TMP_DIR/repo"
HOST_HOME="$TMP_DIR/host-home"
FAKE_BIN="$TMP_DIR/bin"
FAKE_DOCKER_LOG="$TMP_DIR/docker.log"
TOPIC="agent-selftest"

mkdir -p \
  "$TEST_REPO/scripts" \
  "$TEST_REPO/containers/agent" \
  "$HOST_HOME/.codex" \
  "$FAKE_BIN"

TEST_REPO="$(cd "$TEST_REPO" && pwd -P)"
HOST_HOME="$(cd "$HOST_HOME" && pwd -P)"
FAKE_BIN="$(cd "$FAKE_BIN" && pwd -P)"
FAKE_DOCKER_LOG="$(cd "$TMP_DIR" && pwd -P)/docker.log"

cp "$ROOT_DIR/scripts/start-shell.sh" "$TEST_REPO/scripts/start-shell.sh"
cp "$ROOT_DIR/scripts/start-agent.sh" "$TEST_REPO/scripts/start-agent.sh"
chmod +x "$TEST_REPO/scripts/start-shell.sh" "$TEST_REPO/scripts/start-agent.sh"

cat >"$TEST_REPO/scripts/init-worktree.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

TOPIC="${1:?missing topic}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$REPO_ROOT/work/$TOPIC/.home"
EOF
chmod +x "$TEST_REPO/scripts/init-worktree.sh"

cat >"$TEST_REPO/containers/agent/Dockerfile" <<'EOF'
FROM scratch
EOF

cat >"$FAKE_BIN/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_DOCKER_LOG:?missing log path}"

if [ "$#" -ge 3 ] && [ "$1" = "image" ] && [ "$2" = "inspect" ]; then
  exit 1
fi
EOF
chmod +x "$FAKE_BIN/docker"

EXPECTED_TAG="agent:$(hash_file_sha256 "$TEST_REPO/containers/agent/Dockerfile")"

(
  cd "$TEST_REPO"
  PATH="$FAKE_BIN:$PATH" \
  HOME="$HOST_HOME" \
  FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
  ./scripts/start-shell.sh "$TOPIC" go version
)

grep -F "image inspect ${EXPECTED_TAG}" "$FAKE_DOCKER_LOG" >/dev/null
grep -F "build --pull -t ${EXPECTED_TAG} -f containers/agent/Dockerfile ." "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "--hostname ${TOPIC}" "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "--user $(id -u):$(id -g)" "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "-e HOME=$TEST_REPO/work/$TOPIC/.home" "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "-e GOPATH=$TEST_REPO/work/$TOPIC/.home/go" "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "-e GOCACHE=$TEST_REPO/work/$TOPIC/.home/.cache/go-build" "$FAKE_DOCKER_LOG" >/dev/null
grep -F -- "-e GOMODCACHE=$TEST_REPO/work/$TOPIC/.home/go/pkg/mod" "$FAKE_DOCKER_LOG" >/dev/null
grep -F "PS1='[busdk:\h \W]" "$TEST_REPO/work/$TOPIC/.home/.bashrc" >/dev/null
grep -F '\$ ' "$TEST_REPO/work/$TOPIC/.home/.bashrc" >/dev/null
grep -F -- "-v $HOST_HOME/.codex:$TEST_REPO/work/$TOPIC/.home/.codex:rw" "$FAKE_DOCKER_LOG" >/dev/null
if grep -F -- "-v $HOST_HOME/.gitconfig:$TEST_REPO/work/$TOPIC/.home/.gitconfig:ro" "$FAKE_DOCKER_LOG" >/dev/null; then
  echo "unexpected gitconfig mount without host file" >&2
  exit 1
fi
if grep -F -- " -it " "$FAKE_DOCKER_LOG" >/dev/null; then
  echo "expected non-interactive test run to omit -it" >&2
  exit 1
fi
if grep -F -- "-e PS1=" "$FAKE_DOCKER_LOG" >/dev/null; then
  echo "expected prompt to come from worktree .bashrc instead of docker env" >&2
  exit 1
fi
grep -F " ${EXPECTED_TAG} go version" "$FAKE_DOCKER_LOG" >/dev/null

: >"$FAKE_DOCKER_LOG"

(
  cd "$TEST_REPO"
  PATH="$FAKE_BIN:$PATH" \
  HOME="$HOST_HOME" \
  FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
  ./scripts/start-shell.sh "$TOPIC"
)

grep -F " ${EXPECTED_TAG} bash" "$FAKE_DOCKER_LOG" >/dev/null

: >"$FAKE_DOCKER_LOG"

(
  cd "$TEST_REPO"
  PATH="$FAKE_BIN:$PATH" \
  HOME="$HOST_HOME" \
  FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
  ./scripts/start-agent.sh "$TOPIC" --version
)

grep -F " ${EXPECTED_TAG} codex --version" "$FAKE_DOCKER_LOG" >/dev/null

cat >"$FAKE_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 99
EOF
chmod +x "$FAKE_BIN/shasum"

cat >"$FAKE_BIN/sha256sum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
/usr/bin/env python3 - "$1" <<'PY'
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
print(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path}")
PY
EOF
chmod +x "$FAKE_BIN/sha256sum"

: >"$FAKE_DOCKER_LOG"

(
  cd "$TEST_REPO"
  PATH="$FAKE_BIN:$PATH" \
  HOME="$HOST_HOME" \
  FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
  ./scripts/start-shell.sh "$TOPIC" go version
)

grep -F "image inspect ${EXPECTED_TAG}" "$FAKE_DOCKER_LOG" >/dev/null
grep -F " ${EXPECTED_TAG} go version" "$FAKE_DOCKER_LOG" >/dev/null
