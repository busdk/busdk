#!/bin/sh
set -eu

# Builds the SSH-Docker worker image on a remote development host. This avoids
# slow local image uploads when the remote host already has a BusDK checkout,
# SSH-agent access to private submodules, Docker, and a faster network path.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SSH_TARGET=${BUS_REMOTE_WORKER_BUILD_SSH_TARGET:-coding-agent@dev.hg.fi}
SSH_MODE=${BUS_REMOTE_WORKER_BUILD_SSH_MODE:-command}
REMOTE_ROOT=${BUS_REMOTE_WORKER_BUILD_REMOTE_ROOT:-/home/coding-agent/coding-agent/git/busdk/busdk}
REMOTE_NAME=${BUS_REMOTE_WORKER_BUILD_REMOTE_NAME:-origin}
REPO_URL=${BUS_REMOTE_WORKER_BUILD_REPO_URL:-}
BRANCH=${BUS_REMOTE_WORKER_BUILD_BRANCH:-}
IMAGE=${BUS_REMOTE_WORKER_BUILD_IMAGE:-bus-integration-dev-task:local-image-smoke}
PLATFORM=${BUS_REMOTE_WORKER_BUILD_PLATFORM:-linux/amd64}
GO_VERSION=${BUS_REMOTE_WORKER_BUILD_GO_VERSION:-1.26.3}
SUBMODULE_MODE=${BUS_REMOTE_WORKER_BUILD_SUBMODULE_MODE:-pinned}
SUBMODULES=${BUS_REMOTE_WORKER_BUILD_SUBMODULES:-"bus bus-dev bus-integration-dev-task bus-lint bus-notes bus-operator-token bus-integration-docker bus-integration-containers logs"}
PUSH_FIRST=${BUS_REMOTE_WORKER_BUILD_PUSH_FIRST:-false}
REQUIRE_CLEAN=${BUS_REMOTE_WORKER_BUILD_REQUIRE_CLEAN:-true}
BOOTSTRAP_CHECKOUT=${BUS_REMOTE_WORKER_BUILD_BOOTSTRAP_CHECKOUT:-true}
REFUSE_ROOT=${BUS_REMOTE_WORKER_BUILD_REFUSE_ROOT:-}

if [ -z "$BRANCH" ]; then
	BRANCH=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
	if [ "$BRANCH" = HEAD ]; then
		BRANCH=main
	fi
fi

if [ -z "$REPO_URL" ]; then
	REPO_URL=$(git -C "$ROOT" remote get-url "$REMOTE_NAME")
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

case "$BOOTSTRAP_CHECKOUT" in
	true|1|yes|on|false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_BOOTSTRAP_CHECKOUT=%s\n' "$BOOTSTRAP_CHECKOUT" >&2
		exit 2
		;;
esac

case "$SSH_MODE" in
	command|gateway-tty)
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_SSH_MODE=%s; expected command or gateway-tty\n' "$SSH_MODE" >&2
		exit 2
		;;
esac

if [ -z "$REFUSE_ROOT" ] && [ "$SSH_MODE" = gateway-tty ]; then
	REFUSE_ROOT=true
fi

case "$REFUSE_ROOT" in
	true|1|yes|on|false|0|no|off|'')
		;;
	*)
		printf 'invalid BUS_REMOTE_WORKER_BUILD_REFUSE_ROOT=%s\n' "$REFUSE_ROOT" >&2
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
repo_url_q=$(shell_quote "$REPO_URL")
branch_q=$(shell_quote "$BRANCH")
image_q=$(shell_quote "$IMAGE")
platform_q=$(shell_quote "$PLATFORM")
go_version_q=$(shell_quote "$GO_VERSION")
bootstrap_checkout_q=$(shell_quote "$BOOTSTRAP_CHECKOUT")
refuse_root_q=$(shell_quote "$REFUSE_ROOT")
submodules_q=
for module in $SUBMODULES; do
	submodules_q="$submodules_q $(shell_quote "$module")"
done

remote_script="
set -eu
case $refuse_root_q in
	true|1|yes|on)
		if [ \"\$(id -u)\" = 0 ]; then
			printf 'refusing to prepare SSH-Docker worker host as root; fix the remote account or set BUS_REMOTE_WORKER_BUILD_REFUSE_ROOT=false intentionally\n' >&2
			exit 2
		fi
		;;
esac
export GIT_SSH_COMMAND=\${GIT_SSH_COMMAND:-ssh -o StrictHostKeyChecking=accept-new}
remote_root=$remote_root_q
case $bootstrap_checkout_q in
	true|1|yes|on)
		if [ ! -d \"\$remote_root/.git\" ]; then
			if [ -e \"\$remote_root\" ] && [ \"\$(find \"\$remote_root\" -mindepth 1 -maxdepth 1 2>/dev/null | sed -n '1p')\" ]; then
				printf 'remote path exists but is not a Git checkout: %s\n' \"\$remote_root\" >&2
				exit 2
			fi
			parent=\${remote_root%/*}
			if [ \"\$parent\" = \"\$remote_root\" ]; then
				parent=.
			fi
			mkdir -p \"\$parent\"
			git clone --origin $remote_name_q --recurse-submodules=no $repo_url_q \"\$remote_root\"
		fi
		;;
esac
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

case "$SSH_MODE" in
	command)
		ssh -A "$SSH_TARGET" "$remote_script"
		;;
	gateway-tty)
		{
			printf '%s\n' "$remote_script"
			printf '%s\n' "exit"
		} | ssh -A -tt "$SSH_TARGET"
		;;
esac
