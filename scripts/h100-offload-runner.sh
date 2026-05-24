#!/usr/bin/env sh
set -eu

mode=preflight
ssh_target=dev@ai.hg.fi
remote_root=/home/dev/workspace/busdk/busdk
model=gemma4:31b
reasoning_effort=medium
branch_prefix=codex/h100-offload
events_url=http://127.0.0.1:8081
image=bus-integration-dev-task:h100-smoke
timeout=300
ensure_services=false
compose_file=compose.dev-task-docker.yaml
services="bus-events bus-integration-docker bus-integration-containers"
docker_socket=auto

usage() {
	cat <<USAGE
usage: h100-offload-runner.sh [options]

Run bounded H100 offload preflight, sync guidance, or a local-model smoke.

Options:
  --mode MODE              preflight, sync, or smoke (default: $mode)
  --ssh-target TARGET      H100 SSH target (default: $ssh_target)
  --remote-root DIR        remote BusDK checkout (default: $remote_root)
  --model MODEL            Ollama model for checks/smoke (default: $model)
  --reasoning-effort NAME  none|minimal|low|medium|high|xhigh|hard
  --branch-prefix PREFIX   branch prefix for smoke branches
  --events-url URL         Events URL as seen from H100 (default: $events_url)
  --image IMAGE            worker image expected on H100 (default: $image)
  --timeout SECONDS        bounded command timeout (default: $timeout)
  --ensure-services        Start minimal H100 Bus services before preflight
  --compose-file FILE      Compose file for --ensure-services
  --services "A B ..."     Compose services for --ensure-services
  --docker-socket PATH|auto
                           Docker socket for --ensure-services (default: auto)
  -h, --help               show this help
USAGE
}

die() {
	printf 'h100-offload-runner: %s\n' "$*" >&2
	exit 2
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		die "missing value for $1"
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--mode) need_arg "$@"; mode=$2; shift 2 ;;
		--ssh-target) need_arg "$@"; ssh_target=$2; shift 2 ;;
		--remote-root) need_arg "$@"; remote_root=$2; shift 2 ;;
		--model) need_arg "$@"; model=$2; shift 2 ;;
		--reasoning-effort|--reasoning) need_arg "$@"; reasoning_effort=$2; shift 2 ;;
		--branch-prefix) need_arg "$@"; branch_prefix=$2; shift 2 ;;
		--events-url) need_arg "$@"; events_url=$2; shift 2 ;;
		--image) need_arg "$@"; image=$2; shift 2 ;;
		--timeout) need_arg "$@"; timeout=$2; shift 2 ;;
		--ensure-services) ensure_services=true; shift ;;
		--compose-file) need_arg "$@"; compose_file=$2; shift 2 ;;
		--services) need_arg "$@"; services=$2; shift 2 ;;
		--docker-socket) need_arg "$@"; docker_socket=$2; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) die "unknown option: $1" ;;
	esac
done

case "$mode" in
	preflight|sync|smoke) ;;
	*) die "--mode must be preflight, sync, or smoke" ;;
esac
case "$timeout" in
	''|*[!0-9]*) die "--timeout must be a positive integer" ;;
	0) die "--timeout must be a positive integer" ;;
esac
case "$reasoning_effort" in
	none|minimal|low|medium|high|xhigh|hard) ;;
	*) die "invalid --reasoning-effort: $reasoning_effort" ;;
esac
command -v ssh >/dev/null 2>&1 || die "ssh is required"

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

bounded_ssh() {
	tmp=$(mktemp "${TMPDIR:-/tmp}/h100-offload-ssh.XXXXXX")
	status=0
	ssh -A -o BatchMode=yes -o ConnectTimeout=10 "$ssh_target" "$1" >"$tmp" 2>&1 || status=$?
	sed -n '1,120p' "$tmp"
	rm -f "$tmp"
	return "$status"
}

remote_preflight_script() {
	root_q=$(shell_quote "$remote_root")
	model_q=$(shell_quote "$model")
	model_pattern_q=$(shell_quote "\"name\":\"$model\"")
	image_q=$(shell_quote "$image")
	events_q=$(shell_quote "$events_url")
	timeout_q=$(shell_quote "$timeout")
	ensure_q=$(shell_quote "$ensure_services")
	compose_q=$(shell_quote "$compose_file")
	docker_socket_q=$(shell_quote "$docker_socket")
	services_q=
	for service in $services; do
		services_q="$services_q $(shell_quote "$service")"
	done
	printf '%s' "set -eu; command -v timeout >/dev/null 2>&1 || { echo 'missing timeout' >&2; exit 19; }; cd $root_q; dirty=\$(timeout $timeout_q git status --porcelain); if [ -n \"\$dirty\" ]; then printf 'dirty remote checkout at %s\n' $root_q >&2; git status --short | sed -n '1,80p' >&2; exit 20; fi; command -v docker >/dev/null 2>&1 || { echo 'missing docker' >&2; exit 21; }; timeout $timeout_q docker image inspect $image_q >/dev/null 2>&1 || { echo 'missing worker image: '$image_q >&2; exit 22; }; if [ $ensure_q = true ]; then docker_socket=$docker_socket_q; if [ \"\$docker_socket\" = auto ]; then case \"\${DOCKER_HOST:-}\" in unix://*) docker_socket=\${DOCKER_HOST#unix://} ;; esac; fi; if [ \"\$docker_socket\" = auto ] || [ -z \"\$docker_socket\" ]; then uid=\$(id -u); if [ -S \"/run/user/\$uid/docker.sock\" ]; then docker_socket=/run/user/\$uid/docker.sock; elif [ -S /var/run/docker.sock ]; then docker_socket=/var/run/docker.sock; else echo 'could not locate Docker socket for --ensure-services' >&2; exit 26; fi; fi; BUS_DOCKER_SOCKET_HOST=\"\$docker_socket\" timeout $timeout_q docker compose -f $compose_q up -d --no-deps$services_q >/dev/null; fi; command -v curl >/dev/null 2>&1 || { echo 'missing curl' >&2; exit 23; }; timeout $timeout_q curl -fsS --max-time $timeout_q $events_q/api/v1/events/capabilities >/dev/null || { echo 'missing Events capabilities at '$events_q >&2; exit 24; }; timeout $timeout_q curl -fsS --max-time $timeout_q http://127.0.0.1:11434/api/tags | grep -F $model_pattern_q >/dev/null || { echo 'missing Ollama model: '$model_q >&2; exit 25; }; printf 'preflight ok: root=%s image=%s model=%s events=%s\n' $root_q $image_q $model_q $events_q"
}

run_preflight() {
	printf 'h100-offload-runner: preflight target=%s root=%s model=%s image=%s ensure_services=%s\n' "$ssh_target" "$remote_root" "$model" "$image" "$ensure_services" >&2
	if ! output=$(bounded_ssh "$(remote_preflight_script)"); then
		printf '%s\n' "$output" >&2
		return 1
	fi
	printf '%s\n' "$output"
}

run_sync() {
	run_preflight >/dev/null
	cat <<SYNC
H100 source sync is intentionally explicit.

Recommended commands:
  ./scripts/push-submodules.sh
  ssh -A $(shell_quote "$ssh_target") "cd $(shell_quote "$remote_root") && git fetch origin main && git checkout main && git pull --ff-only && git submodule update --init --recursive"

After sync, rerun:
  scripts/h100-offload-runner.sh --mode preflight --ssh-target $(shell_quote "$ssh_target") --remote-root $(shell_quote "$remote_root")
SYNC
}

run_smoke() {
	if [ ! -x scripts/test-h100-local-model-write-smoke.sh ]; then
		die "scripts/test-h100-local-model-write-smoke.sh is required for smoke mode"
	fi
	stamp=$(date +%Y%m%d%H%M%S)
	branch="${branch_prefix}-${stamp}"
	exec scripts/test-h100-local-model-write-smoke.sh \
		--ssh-target "$ssh_target" \
		--remote-root "$remote_root" \
		--model "$model" \
		--reasoning-effort "$reasoning_effort" \
		--branch "$branch" \
		--run-ssh-wait-timeout "$timeout" \
		--verify-ssh-wait-timeout "$timeout" \
		--wait-timeout "${timeout}s"
}

case "$mode" in
	preflight) run_preflight ;;
	sync) run_sync ;;
	smoke) run_smoke ;;
esac
