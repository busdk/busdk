#!/bin/sh
set -eu

# Prepares a disposable SSH-Docker worker host from durable inputs. The host is
# allowed to lose local disk state: this script can bootstrap/update the Git
# checkout, sync pinned submodules, build the worker image, and start the
# Compose services needed by image-backed workers.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SSH_TARGET=${BUS_SSH_DOCKER_PREPARE_SSH_TARGET:-${BUS_REMOTE_WORKER_BUILD_SSH_TARGET:-coding-agent@dev.hg.fi}}
SSH_MODE=${BUS_SSH_DOCKER_PREPARE_SSH_MODE:-${BUS_REMOTE_WORKER_BUILD_SSH_MODE:-command}}
REMOTE_ROOT=${BUS_SSH_DOCKER_PREPARE_REMOTE_ROOT:-${BUS_REMOTE_WORKER_BUILD_REMOTE_ROOT:-/home/coding-agent/coding-agent/git/busdk/busdk}}
COMPOSE_FILE=${BUS_SSH_DOCKER_PREPARE_COMPOSE_FILE:-compose.yaml}
COMPOSE_PROFILE=${BUS_SSH_DOCKER_PREPARE_COMPOSE_PROFILE:-dev-task}
IMAGE=${BUS_SSH_DOCKER_PREPARE_IMAGE:-${BUS_REMOTE_WORKER_BUILD_IMAGE:-bus-integration-dev-task:local-image-smoke}}
SERVICES=${BUS_SSH_DOCKER_PREPARE_SERVICES:-bus-events}
SERVICE_SUBMODULES=${BUS_SSH_DOCKER_PREPARE_SERVICE_SUBMODULES:-"bus-api-provider-auth bus-api-provider-events bus-events bus-help"}
BUILD_IMAGE=${BUS_SSH_DOCKER_PREPARE_BUILD_IMAGE:-true}
START_SERVICES=${BUS_SSH_DOCKER_PREPARE_START_SERVICES:-true}
REFUSE_ROOT=${BUS_SSH_DOCKER_PREPARE_REFUSE_ROOT:-${BUS_REMOTE_WORKER_BUILD_REFUSE_ROOT:-}}

if [ -z "$REFUSE_ROOT" ] && [ "$SSH_MODE" = gateway-tty ]; then
	REFUSE_ROOT=true
fi

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

case "$BUILD_IMAGE" in
	true|1|yes|on)
		BUS_REMOTE_WORKER_BUILD_SSH_TARGET="$SSH_TARGET" \
		BUS_REMOTE_WORKER_BUILD_SSH_MODE="$SSH_MODE" \
		BUS_REMOTE_WORKER_BUILD_REMOTE_ROOT="$REMOTE_ROOT" \
		BUS_REMOTE_WORKER_BUILD_IMAGE="$IMAGE" \
		BUS_REMOTE_WORKER_BUILD_REFUSE_ROOT="$REFUSE_ROOT" \
		"$ROOT/scripts/build-ssh-docker-worker-image-remote.sh"
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_PREPARE_BUILD_IMAGE=%s\n' "$BUILD_IMAGE" >&2
		exit 2
		;;
esac

case "$START_SERVICES" in
	true|1|yes|on)
		remote_root_q=$(shell_quote "$REMOTE_ROOT")
		compose_file_q=$(shell_quote "$COMPOSE_FILE")
		compose_profile_q=$(shell_quote "$COMPOSE_PROFILE")
		image_q=$(shell_quote "$IMAGE")
		refuse_root_q=$(shell_quote "$REFUSE_ROOT")
		service_submodules_q=
		for module in $SERVICE_SUBMODULES; do
			service_submodules_q="$service_submodules_q $(shell_quote "$module")"
		done
		services_q=
		for service in $SERVICES; do
			services_q="$services_q $(shell_quote "$service")"
		done
		remote_script="
set -eu
case $refuse_root_q in
	true|1|yes|on)
	if [ \"\$(id -u)\" = 0 ]; then
		printf 'refusing to prepare SSH-Docker worker host as root; fix the remote account or set BUS_SSH_DOCKER_PREPARE_REFUSE_ROOT=false intentionally\n' >&2
		exit 2
	fi
	;;
esac
cd $remote_root_q
git submodule update --init --recursive$service_submodules_q
docker compose -f $compose_file_q --profile $compose_profile_q up -d$services_q
docker compose -f $compose_file_q --profile $compose_profile_q ps$services_q
docker image inspect $image_q --format '{{.Id}}'
"
		case "$SSH_MODE" in
			command)
				printf '%s\n' "$remote_script" | ssh -A "$SSH_TARGET" sh -s
				;;
			gateway-tty)
				printf '%s\n' "$remote_script" | "$ROOT/scripts/ssh-gateway-tty-run.sh" "$SSH_TARGET"
				;;
			*)
				printf 'invalid BUS_SSH_DOCKER_PREPARE_SSH_MODE=%s; expected command or gateway-tty\n' "$SSH_MODE" >&2
				exit 2
				;;
		esac
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_PREPARE_START_SERVICES=%s\n' "$START_SERVICES" >&2
		exit 2
		;;
esac
