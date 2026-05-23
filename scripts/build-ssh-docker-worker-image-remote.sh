#!/bin/sh
set -eu

# Builds the SSH-Docker worker image on a remote development host. This avoids
# slow local image uploads when the remote host already has a BusDK checkout,
# SSH-agent access to private submodules, Docker, and a faster network path.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SSH_TARGET=${BUS_REMOTE_WORKER_BUILD_SSH_TARGET:-coding-agent@dev.hg.fi}
REMOTE_ROOT=${BUS_REMOTE_WORKER_BUILD_REMOTE_ROOT:-/home/coding-agent/coding-agent/git/busdk/busdk}
REMOTE_NAME=${BUS_REMOTE_WORKER_BUILD_REMOTE_NAME:-origin}
BRANCH=${BUS_REMOTE_WORKER_BUILD_BRANCH:-}
IMAGE=${BUS_REMOTE_WORKER_BUILD_IMAGE:-bus-integration-dev-task:local-image-smoke}
PLATFORM=${BUS_REMOTE_WORKER_BUILD_PLATFORM:-linux/amd64}
GO_VERSION=${BUS_REMOTE_WORKER_BUILD_GO_VERSION:-1.26.3}
SUBMODULE_MODE=${BUS_REMOTE_WORKER_BUILD_SUBMODULE_MODE:-pinned}
SUBMODULES=${BUS_REMOTE_WORKER_BUILD_SUBMODULES:-"bus bus-dev bus-integration-dev-task bus-lint bus-notes bus-operator-token bus-integration-docker bus-integration-containers logs"}
PUSH_FIRST=${BUS_REMOTE_WORKER_BUILD_PUSH_FIRST:-false}
REQUIRE_CLEAN=${BUS_REMOTE_WORKER_BUILD_REQUIRE_CLEAN:-true}

if [ -z "$BRANCH" ]; then
	BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
	if [ "$BRANCH" = HEAD ]; then
		BRANCH=main
	fi
fi

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

case "$REQUIRE_CLEAN" in
	true|1|yes|on)
		if [ -n "$(git -C "$ROOT" status --short)" ]; then
			printf 'local checkout is dirty; commit or set BUS_REMOTE_WORKER_BUILD_REQUIRE_CLEAN=false\n' >&2
			git -C "$ROOT" status --short >&2
			exit 2
		fi
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_REQUIRE_CLEAN=%s\n' "$REQUIRE_CLEAN" >&2
		exit 2
		;;
esac

case "$PUSH_FIRST" in
	true|1|yes|on)
		"$ROOT/scripts/push-submodules.sh"
		;;
	false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_PUSH_FIRST=%s\n' "$PUSH_FIRST" >&2
		exit 2
		;;
esac

case "$SUBMODULE_MODE" in
	remote)
		submodule_cmd='git submodule update --init --recursive --remote'
		;;
	pinned)
		submodule_cmd='git submodule update --init --recursive'
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_SUBMODULE_MODE=%s; expected remote or pinned\n' "$SUBMODULE_MODE" >&2
		exit 2
		;;
esac

remote_root_q=$(shell_quote "$REMOTE_ROOT")
remote_name_q=$(shell_quote "$REMOTE_NAME")
branch_q=$(shell_quote "$BRANCH")
image_q=$(shell_quote "$IMAGE")
platform_q=$(shell_quote "$PLATFORM")
go_version_q=$(shell_quote "$GO_VERSION")
submodules_q=
for module in $SUBMODULES; do
	submodules_q="$submodules_q $(shell_quote "$module")"
done

remote_script="
set -eu
cd $remote_root_q
git fetch --recurse-submodules=no $remote_name_q $branch_q
git checkout $branch_q
git pull --ff-only $remote_name_q $branch_q
$submodule_cmd $submodules_q
BUS_SSH_DOCKER_BUILD_IMAGE=$image_q \\
BUS_SSH_DOCKER_BUILD_PLATFORM=$platform_q \\
BUS_SSH_DOCKER_BUILD_GO_VERSION=$go_version_q \\
./scripts/build-ssh-docker-worker-image.sh
docker image inspect $image_q --format '{{.Id}}'
"

ssh -A "$SSH_TARGET" "$remote_script"
