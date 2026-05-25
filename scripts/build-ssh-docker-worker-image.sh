#!/bin/sh
set -eu

# Builds the image-backed dev-task worker image from the current checkout.
# The image contains Linux binaries under dist-bin/ and does not require a
# private source checkout at runtime.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=${BUS_SSH_DOCKER_BUILD_IMAGE:-${BUS_SSH_DOCKER_SMOKE_IMAGE:-bus-integration-dev-task:local-image-smoke}}
PLATFORM=${BUS_SSH_DOCKER_BUILD_PLATFORM:-linux/amd64}
GOOS=${BUS_SSH_DOCKER_BUILD_GOOS:-linux}
GOARCH=${BUS_SSH_DOCKER_BUILD_GOARCH:-amd64}
GO_VERSION=${BUS_SSH_DOCKER_BUILD_GO_VERSION:-1.26.3}
CODEX_NPM_VERSION=${BUS_SSH_DOCKER_BUILD_CODEX_NPM_VERSION:-0.133.0}
MODULES=${BUS_SSH_DOCKER_BUILD_MODULES:-bus bus-dev bus-integration-dev-task bus-lint bus-notes bus-operator-token}
DEPENDENCY_MODULES=${BUS_SSH_DOCKER_BUILD_DEPENDENCY_MODULES:-bus-agent bus-events bus-help bus-integration bus-preferences bus-remote bus-secrets bus-update}
BUILD_MODE=${BUS_SSH_DOCKER_BUILD_MODE:-docker}

case "$PLATFORM" in
	linux/amd64)
		GOOS=${BUS_SSH_DOCKER_BUILD_GOOS:-linux}
		GOARCH=${BUS_SSH_DOCKER_BUILD_GOARCH:-amd64}
		;;
	linux/arm64|linux/arm64/v8)
		GOOS=${BUS_SSH_DOCKER_BUILD_GOOS:-linux}
		GOARCH=${BUS_SSH_DOCKER_BUILD_GOARCH:-arm64}
		;;
esac

mkdir -p "$ROOT/dist-bin"

for module in $MODULES; do
	if [ ! -d "$ROOT/$module" ]; then
		printf 'module not found: %s\n' "$module" >&2
		exit 2
	fi
done

for module in $DEPENDENCY_MODULES; do
	if [ ! -d "$ROOT/$module" ]; then
		printf 'dependency module not found: %s\n' "$module" >&2
		exit 2
	fi
done

for module in $MODULES; do
	case "$BUILD_MODE" in
		docker)
			docker run --rm --platform "$PLATFORM" \
				-v "$ROOT:/workspace" \
				-w "/workspace/$module" \
				-e GOCACHE=/tmp/bus-go-build-cache \
				-e GOPATH=/tmp/bus-go \
				"golang:$GO_VERSION" \
				make -B build
			;;
		host)
			GOOS="$GOOS" GOARCH="$GOARCH" CGO_ENABLED=0 make -B -C "$ROOT/$module" build
			;;
		*)
			printf 'invalid BUS_SSH_DOCKER_BUILD_MODE=%s\n' "$BUILD_MODE" >&2
			exit 2
			;;
	esac
	if [ ! -x "$ROOT/$module/bin/$module" ]; then
		printf 'expected binary not found after build: %s\n' "$ROOT/$module/bin/$module" >&2
		exit 2
	fi
	install -m 0755 "$ROOT/$module/bin/$module" "$ROOT/dist-bin/$module"
done

docker build \
	--platform "$PLATFORM" \
	--build-arg "GO_VERSION=$GO_VERSION" \
	--build-arg "CODEX_NPM_VERSION=$CODEX_NPM_VERSION" \
	-t "$IMAGE" \
	-f "$ROOT/deploy/local-ai-platform/codex/dev-task-worker.Dockerfile" \
	"$ROOT"

docker run --rm --platform "$PLATFORM" "$IMAGE" bus-integration-dev-task --help >/dev/null
docker run --rm --platform "$PLATFORM" \
	-e BUS_DEV_TASK_IMAGE_DRY_RUN=true \
	-e BUS_EVENTS_API_URL=http://worker-reachable-events.example.invalid \
	-e BUS_API_TOKEN=redacted-placeholder \
	-e BUS_DEV_TASK_RECIPIENT=bus-dev \
	-e BUS_DEV_TASK_WORK_REF=busdk#image-smoke \
	-e BUS_DEV_TASK_AGENT_BACKEND=container \
	-e BUS_DEV_TASK_CONTAINER_IMAGE="$IMAGE" \
	-e BUS_DEV_TASK_CONTAINER_PROFILE=local-model \
	-e BUS_DEV_TASK_COMMAND_JSON='["sh","-lc","curl --version >/dev/null && git --version >/dev/null && make --version >/dev/null"]' \
	-e BUS_DEV_TASK_COMMIT=false \
	"$IMAGE" >/dev/null

printf '%s\n' "$IMAGE"
