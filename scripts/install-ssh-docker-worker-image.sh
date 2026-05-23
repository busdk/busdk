#!/bin/sh
set -eu

# Installs a locally available worker image onto an SSH-Docker remote through
# the Bus operator-deploy image installer. This keeps private image transfer in
# one reusable product path instead of ad hoc docker save | ssh docker load.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

REMOTE_ID=${BUS_SSH_DOCKER_INSTALL_REMOTE_ID:-${BUS_SSH_DOCKER_SMOKE_REMOTE_ID:-dev-hg}}
SSH_TARGET=${BUS_SSH_DOCKER_INSTALL_SSH_TARGET:-${BUS_SSH_DOCKER_SMOKE_SSH_TARGET:-coding-agent@dev.hg.fi}}
LOCAL_TAG=${BUS_SSH_DOCKER_INSTALL_LOCAL_TAG:-${BUS_SSH_DOCKER_SMOKE_IMAGE:-bus-integration-dev-task:local-image-smoke}}
REMOTE_IMAGE=${BUS_SSH_DOCKER_INSTALL_IMAGE:-${BUS_SSH_DOCKER_SMOKE_IMAGE:-$LOCAL_TAG}}
REMOTE_PLATFORM=${BUS_SSH_DOCKER_INSTALL_REMOTE_PLATFORM:-linux/amd64}
REMOTE_TIMEOUT=${BUS_SSH_DOCKER_INSTALL_REMOTE_TIMEOUT_SECONDS:-900}
DRY_RUN=${BUS_SSH_DOCKER_INSTALL_DRY_RUN:-false}

if [ ! -x "$ROOT/bus-operator-deploy/bin/bus-operator-deploy" ]; then
	printf 'missing bus-operator-deploy binary; run make -C bus-operator-deploy build\n' >&2
	exit 2
fi

allowed_env='BUS_SSH_DOCKER_INSTALL_REMOTE_ID,BUS_SSH_DOCKER_SMOKE_REMOTE_ID,BUS_SSH_DOCKER_INSTALL_SSH_TARGET,BUS_SSH_DOCKER_SMOKE_SSH_TARGET,BUS_SSH_DOCKER_INSTALL_LOCAL_TAG,BUS_SSH_DOCKER_SMOKE_IMAGE,BUS_SSH_DOCKER_INSTALL_IMAGE,BUS_SSH_DOCKER_INSTALL_REMOTE_PLATFORM,BUS_SSH_DOCKER_INSTALL_REMOTE_TIMEOUT_SECONDS,BUS_SSH_DOCKER_INSTALL_DRY_RUN'
if [ -n "${BUS_OPERATOR_DEPLOY_ENV_ALLOW:-}" ]; then
	BUS_OPERATOR_DEPLOY_ENV_ALLOW="${BUS_OPERATOR_DEPLOY_ENV_ALLOW},${allowed_env}"
else
	BUS_OPERATOR_DEPLOY_ENV_ALLOW="$allowed_env"
fi
export BUS_OPERATOR_DEPLOY_ENV_ALLOW

set -- "$ROOT/bus-operator-deploy/bin/bus-operator-deploy" worker image install \
	--remote-id "$REMOTE_ID" \
	--remote-kind ssh-docker \
	--ssh-url "$SSH_TARGET" \
	--image "$REMOTE_IMAGE" \
	--local-tag "$LOCAL_TAG" \
	--remote-platform "$REMOTE_PLATFORM" \
	--remote-timeout-seconds "$REMOTE_TIMEOUT"

case "$DRY_RUN" in
	true|1|yes|on)
		set -- "$@" --dry-run
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_SSH_DOCKER_INSTALL_DRY_RUN=%s\n' "$DRY_RUN" >&2
		exit 2
		;;
esac

exec "$@"
