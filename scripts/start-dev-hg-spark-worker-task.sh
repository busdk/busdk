#!/bin/sh
set -eu

# Starts one manual dev-hg SSH-Docker Codex App Server worker task.
# This is a bootstrap launcher, not the final bus-workers control plane.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib-worker-template.sh"

MODULE=${1:-}
BRANCH=${2:-}
PROMPT_FILE=${3:-}

if [ -z "$MODULE" ] || [ -z "$BRANCH" ] || [ -z "$PROMPT_FILE" ]; then
	cat >&2 <<'USAGE'
usage: start-dev-hg-spark-worker-task.sh MODULE BRANCH PROMPT_FILE

Starts a single Codex App Server worker container on coding-agent@dev.hg.fi
using an environment-local worker template. The worker gets a task worktree
and implementation branch. The prompt should ask only for implementation plus
unit tests; do not ask for e2e or integration tests here.

Environment overrides:
  BUS_DEV_HG_SPARK_START_REMOTE_ID      default dev-hg
  BUS_DEV_HG_SPARK_START_TEMPLATE       default codex-53-spark
  BUS_DEV_HG_SPARK_START_IMAGE          default bus-integration-task:local-image-smoke
  BUS_DEV_HG_SPARK_START_LOCAL_TAG      default bus-integration-task:local-image-smoke
  BUS_DEV_HG_SPARK_START_INSTALL_IMAGE  default false
  BUS_DEV_HG_SPARK_START_BUILD_IMAGE    default false
  BUS_DEV_HG_SPARK_START_SANDBOX        default full
  BUS_DEV_HG_SPARK_START_WRITE_SCOPE    default MODULE
  BUS_DEV_HG_SPARK_START_SMOKE_DIR      default /tmp/bus-dev-hg-spark-workers
  BUS_DEV_HG_SPARK_START_PROMPT_PROFILE default minimal-implement
  BUS_DEV_HG_SPARK_START_START_ONLY     default false
  BUS_DEV_HG_SPARK_START_ONCE           default false
  BUS_DEV_HG_SPARK_START_WAIT_TIMEOUT   default 45m
USAGE
	exit 2
fi

if [ ! -f "$PROMPT_FILE" ]; then
	printf 'prompt file not found: %s\n' "$PROMPT_FILE" >&2
	exit 2
fi

REMOTE_ID=${BUS_DEV_HG_SPARK_START_REMOTE_ID:-dev-hg}
TEMPLATE=${BUS_DEV_HG_SPARK_START_TEMPLATE:-codex-53-spark}
IMAGE=${BUS_DEV_HG_SPARK_START_IMAGE:-bus-integration-task:local-image-smoke}
LOCAL_TAG=${BUS_DEV_HG_SPARK_START_LOCAL_TAG:-bus-integration-task:local-image-smoke}
INSTALL_IMAGE=${BUS_DEV_HG_SPARK_START_INSTALL_IMAGE:-false}
BUILD_IMAGE=${BUS_DEV_HG_SPARK_START_BUILD_IMAGE:-false}
SANDBOX=${BUS_DEV_HG_SPARK_START_SANDBOX:-full}
WRITE_SCOPE=${BUS_DEV_HG_SPARK_START_WRITE_SCOPE:-$MODULE}
SMOKE_DIR=${BUS_DEV_HG_SPARK_START_SMOKE_DIR:-${TMPDIR:-/tmp}/bus-dev-hg-spark-workers}
START_TIMEOUT=${BUS_DEV_HG_SPARK_START_TIMEOUT:-5m}
WAIT_TIMEOUT=${BUS_DEV_HG_SPARK_START_WAIT_TIMEOUT:-45m}
START_ONLY=${BUS_DEV_HG_SPARK_START_START_ONLY:-false}
AUTH_MODE=${BUS_DEV_HG_SPARK_START_AUTH_MODE:-chatgpt-subscription}
TASK_PROMPT_PROFILE=${BUS_DEV_HG_SPARK_START_PROMPT_PROFILE:-minimal-implement}
TASK_ONCE=${BUS_DEV_HG_SPARK_START_ONCE:-false}

resolve_worker_template "$ROOT" "$TEMPLATE"
MODEL=${BUS_DEV_HG_SPARK_START_MODEL:-$BUS_WORKER_TEMPLATE_MODEL}
PROFILE=${BUS_DEV_HG_SPARK_START_PROFILE:-$BUS_WORKER_TEMPLATE_PROFILE}
REASONING_EFFORT=${BUS_DEV_HG_SPARK_START_REASONING_EFFORT:-$BUS_WORKER_TEMPLATE_REASONING_EFFORT}

PROMPT=$(cat "$PROMPT_FILE")

BUS_TASK_PROMPT_PROFILE="$TASK_PROMPT_PROFILE" \
BUS_TASK_ONCE="$TASK_ONCE" \
exec "$ROOT/scripts/test-ssh-docker-image-smoke.sh" \
	--remote-id "$REMOTE_ID" \
	--smoke-dir "$SMOKE_DIR" \
	--agent-backend codex-appserver \
	--worker-template "$TEMPLATE" \
	--worker-profile "$PROFILE" \
	--codex-model "$MODEL" \
	--reasoning-effort "$REASONING_EFFORT" \
	--worker-sandbox "$SANDBOX" \
	--auth-mode "$AUTH_MODE" \
	--image "$IMAGE" \
	--local-tag "$LOCAL_TAG" \
	--install-image="$INSTALL_IMAGE" \
	--build-image="$BUILD_IMAGE" \
	--worktree=true \
	--commit=false \
	--start-only="$START_ONLY" \
	--start-timeout "$START_TIMEOUT" \
	--wait-timeout "$WAIT_TIMEOUT" \
	--recipient "$MODULE" \
	--write-scope "$WRITE_SCOPE" \
	--new-branch "$BRANCH" \
	--prompt "$PROMPT"
