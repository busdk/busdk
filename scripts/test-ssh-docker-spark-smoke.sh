#!/bin/sh
set -eu

# Runs the real SSH-Docker Codex App Server smoke with defaults tuned for the
# Spark-quota worker lane on dev-hg. This is the reusable operator path for
# verifying that a hosted subscription-backed Spark worker can claim a task,
# report through Bus Events, and finish without editing files.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib-worker-template.sh"

REMOTE_ID=${BUS_SSH_DOCKER_SPARK_SMOKE_REMOTE_ID:-dev-hg}
TEMPLATE=${BUS_SSH_DOCKER_SPARK_SMOKE_TEMPLATE:-codex-53-spark}
PROFILE=${BUS_SSH_DOCKER_SPARK_SMOKE_PROFILE:-}
MODEL=${BUS_SSH_DOCKER_SPARK_SMOKE_MODEL:-}
REASONING_EFFORT=${BUS_SSH_DOCKER_SPARK_SMOKE_REASONING_EFFORT:-}
SANDBOX=${BUS_SSH_DOCKER_SPARK_SMOKE_SANDBOX:-read}
AUTH_MODE=${BUS_SSH_DOCKER_SPARK_SMOKE_AUTH_MODE:-chatgpt-subscription}
WORKER_IMAGE=${BUS_SSH_DOCKER_SPARK_SMOKE_IMAGE:-ghcr.io/busdk/bus-integration-task:latest}
LOCAL_TAG=${BUS_SSH_DOCKER_SPARK_SMOKE_LOCAL_TAG:-bus-integration-task:local-image-smoke}
INSTALL_IMAGE=${BUS_SSH_DOCKER_SPARK_SMOKE_INSTALL_IMAGE:-false}
BUILD_IMAGE=${BUS_SSH_DOCKER_SPARK_SMOKE_BUILD_IMAGE:-false}
CREDENTIAL_SOURCE_KIND=${BUS_SSH_DOCKER_SPARK_SMOKE_CREDENTIAL_SOURCE_KIND:-}
CREDENTIAL_SOURCE_REF=${BUS_SSH_DOCKER_SPARK_SMOKE_CREDENTIAL_SOURCE_REF:-}
PROMPT=${BUS_SSH_DOCKER_SPARK_SMOKE_PROMPT:-SSH-Docker Spark smoke: do not edit files. Inspect /workspace/bus-dev/go.mod, report the module path in one sentence, and finish with app_server_closeout JSON where task_complete=true, changed_files=[], plan_closed=false, no_matching_plan_item=true, no_matching_plan_reason explains this is a read-only Spark smoke, required_checks includes the go.mod inspection, and remaining_blockers=[]. Do not run bus task close; the bridge will publish the terminal event. If Bus Notes are unavailable, state that as non-blocking evidence, not as a blocker.}
START_TIMEOUT=${BUS_SSH_DOCKER_SPARK_SMOKE_START_TIMEOUT:-5m}
WAIT_TIMEOUT=${BUS_SSH_DOCKER_SPARK_SMOKE_WAIT_TIMEOUT:-15m}
EVIDENCE_DIR=${BUS_SSH_DOCKER_SPARK_SMOKE_EVIDENCE_DIR:-}

usage() {
	cat >&2 <<'USAGE'
usage: test-ssh-docker-spark-smoke.sh [options] [-- lower-level-smoke-options...]

Runs the SSH-Docker read-only Spark smoke with dev-hg-oriented defaults.
Unknown lower-level options can be passed after -- and are forwarded to
test-ssh-docker-codex-smoke.sh.

Options:
  --remote-id ID                 Bus remote id (default: dev-hg)
  --template TEMPLATE            Worker template ref (default: codex-53-spark)
  --profile NAME                 Worker profile label override
  --model MODEL                  Requested worker model override
  --reasoning-effort VALUE       Requested worker reasoning effort
  --sandbox MODE                 Worker sandbox mode: read, write, or full
  --auth-mode MODE               Worker auth mode label (default: chatgpt-subscription)
  --image IMAGE                  Worker launcher image (default: ghcr.io/busdk/bus-integration-task:latest)
  --local-tag TAG                Local source tag for build/install (default: bus-integration-task:local-image-smoke)
  --install-image[=BOOL]         Install the local worker image onto the remote first
  --build-image[=BOOL]           Build the local worker image before install/run
  --credential-source-kind KIND  Non-secret credential source kind label
  --credential-source-ref REF    Non-secret credential source ref label
  --prompt TEXT                  Read-only smoke prompt
  --start-timeout DURATION       Start timeout passed to the lower-level smoke
  --wait-timeout DURATION        Wait timeout passed to the lower-level smoke
  --evidence-dir DIR             Write JSON evidence under DIR
  -h, --help                     Show this help text and exit
USAGE
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		printf 'missing value for %s\n' "$1" >&2
		usage
		exit 2
	fi
}

forwarded_args=

append_forwarded_arg() {
	if [ -z "$forwarded_args" ]; then
		forwarded_args=$1
	else
		forwarded_args="$forwarded_args
$1"
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--remote-id) need_arg "$@"; REMOTE_ID=$2; shift 2 ;;
		--template) need_arg "$@"; TEMPLATE=$2; shift 2 ;;
		--profile) need_arg "$@"; PROFILE=$2; shift 2 ;;
		--model) need_arg "$@"; MODEL=$2; shift 2 ;;
		--reasoning-effort) need_arg "$@"; REASONING_EFFORT=$2; shift 2 ;;
		--sandbox) need_arg "$@"; SANDBOX=$2; shift 2 ;;
		--auth-mode) need_arg "$@"; AUTH_MODE=$2; shift 2 ;;
		--image|--worker-image) need_arg "$@"; WORKER_IMAGE=$2; shift 2 ;;
		--local-tag) need_arg "$@"; LOCAL_TAG=$2; shift 2 ;;
		--install-image) INSTALL_IMAGE=true; shift ;;
		--install-image=*) INSTALL_IMAGE=${1#*=}; shift ;;
		--no-install-image) INSTALL_IMAGE=false; shift ;;
		--build-image) BUILD_IMAGE=true; shift ;;
		--build-image=*) BUILD_IMAGE=${1#*=}; shift ;;
		--no-build-image) BUILD_IMAGE=false; shift ;;
		--credential-source-kind) need_arg "$@"; CREDENTIAL_SOURCE_KIND=$2; shift 2 ;;
		--credential-source-ref) need_arg "$@"; CREDENTIAL_SOURCE_REF=$2; shift 2 ;;
		--prompt) need_arg "$@"; PROMPT=$2; shift 2 ;;
		--start-timeout) need_arg "$@"; START_TIMEOUT=$2; shift 2 ;;
		--wait-timeout) need_arg "$@"; WAIT_TIMEOUT=$2; shift 2 ;;
		--evidence-dir) need_arg "$@"; EVIDENCE_DIR=$2; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		--)
			shift
			while [ "$#" -gt 0 ]; do
				append_forwarded_arg "$1"
				shift
			done
			break
			;;
		*)
			printf 'unknown option: %s\n' "$1" >&2
			usage
			exit 2
			;;
	esac
done

set --
if [ -n "$forwarded_args" ]; then
	OLD_IFS=$IFS
	IFS='
'
	for arg in $forwarded_args; do
		set -- "$@" "$arg"
	done
	IFS=$OLD_IFS
fi

resolve_worker_template "$ROOT" "$TEMPLATE"
PROFILE=${PROFILE:-$BUS_WORKER_TEMPLATE_PROFILE}
MODEL=${MODEL:-$BUS_WORKER_TEMPLATE_MODEL}
REASONING_EFFORT=${REASONING_EFFORT:-$BUS_WORKER_TEMPLATE_REASONING_EFFORT}

BUS_SSH_DOCKER_CODEX_SMOKE_WORKER_TEMPLATE=$TEMPLATE \
BUS_SSH_DOCKER_CODEX_SMOKE_REMOTE_ID=$REMOTE_ID \
BUS_SSH_DOCKER_CODEX_SMOKE_WORKER_PROFILE=$PROFILE \
BUS_SSH_DOCKER_CODEX_SMOKE_MODEL=$MODEL \
BUS_SSH_DOCKER_CODEX_SMOKE_REASONING_EFFORT=$REASONING_EFFORT \
BUS_SSH_DOCKER_CODEX_SMOKE_WORKER_SANDBOX=$SANDBOX \
BUS_SSH_DOCKER_CODEX_SMOKE_AUTH_MODE=$AUTH_MODE \
BUS_SSH_DOCKER_SMOKE_IMAGE=$WORKER_IMAGE \
BUS_SSH_DOCKER_SMOKE_LOCAL_TAG=$LOCAL_TAG \
BUS_SSH_DOCKER_SMOKE_INSTALL_IMAGE=$INSTALL_IMAGE \
BUS_SSH_DOCKER_SMOKE_BUILD_IMAGE=$BUILD_IMAGE \
BUS_SSH_DOCKER_CODEX_SMOKE_CREDENTIAL_SOURCE_KIND=$CREDENTIAL_SOURCE_KIND \
BUS_SSH_DOCKER_CODEX_SMOKE_CREDENTIAL_SOURCE_REF=$CREDENTIAL_SOURCE_REF \
BUS_SSH_DOCKER_CODEX_SMOKE_PROMPT=$PROMPT \
BUS_SSH_DOCKER_CODEX_SMOKE_START_TIMEOUT=$START_TIMEOUT \
BUS_SSH_DOCKER_CODEX_SMOKE_WAIT_TIMEOUT=$WAIT_TIMEOUT \
BUS_SSH_DOCKER_CODEX_SMOKE_EVIDENCE_DIR=$EVIDENCE_DIR \
"$ROOT/scripts/test-ssh-docker-codex-smoke.sh" "$@"
