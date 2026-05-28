#!/usr/bin/env sh
set -eu

mode=preflight
ssh_target=dev@ai.hg.fi
remote_root=/home/dev/workspace/busdk/busdk
model=gemma4:31b
reasoning_effort=medium
branch_prefix=codex/h100-offload
events_url=http://127.0.0.1:8081
image=bus-integration-task:h100-smoke
timeout=300
ensure_services=false
compose_file=compose.yaml
compose_profile=dev-task
services="bus-events bus-docker bus-container-router"
docker_socket=auto
refresh_token=auto
remote_token_file=.config/bus/auth/api-token
token_subject=00000000-0000-4000-8000-000000000001
token_audience=ai.hg.fi/api
token_scope="events:send events:listen dev:task:send dev:task:read dev:task:reply dev:task:claim container:read container:run container:delete container:admin notes.write notes.read notes.search notes.import.task_summary notes.import.session_summary"
token_ttl=12h

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
  --compose-profile NAME   Compose profile for --ensure-services
  --services "A B ..."     Compose services for --ensure-services
  --docker-socket PATH|auto
                           Docker socket for --ensure-services (default: auto)
  --refresh-token          Refresh remote local-development token file
  --no-refresh-token       Do not refresh remote token file
  --remote-token-file FILE Remote token file path (default: $remote_token_file)
  --token-subject ID       Local token subject (default: $token_subject)
  --token-audience AUD     Local token audience (default: $token_audience)
  --token-scope SCOPES     Local token scopes
  --token-ttl DURATION     Local token TTL (default: $token_ttl)
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
		--compose-profile) need_arg "$@"; compose_profile=$2; shift 2 ;;
		--services) need_arg "$@"; services=$2; shift 2 ;;
		--docker-socket) need_arg "$@"; docker_socket=$2; shift 2 ;;
		--refresh-token) refresh_token=true; shift ;;
		--no-refresh-token) refresh_token=false; shift ;;
		--remote-token-file) need_arg "$@"; remote_token_file=$2; shift 2 ;;
		--token-subject) need_arg "$@"; token_subject=$2; shift 2 ;;
		--token-audience) need_arg "$@"; token_audience=$2; shift 2 ;;
		--token-scope) need_arg "$@"; token_scope=$2; shift 2 ;;
		--token-ttl) need_arg "$@"; token_ttl=$2; shift 2 ;;
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
case "$refresh_token" in
	auto|true|false) ;;
	*) die "--refresh-token state must be auto, true, or false" ;;
esac
[ -n "$remote_token_file" ] || die "--remote-token-file must not be empty"
[ -n "$token_subject" ] || die "--token-subject must not be empty"
[ -n "$token_audience" ] || die "--token-audience must not be empty"
[ -n "$token_scope" ] || die "--token-scope must not be empty"
[ -n "$token_ttl" ] || die "--token-ttl must not be empty"
if [ "$refresh_token" = auto ]; then
	if [ "$ensure_services" = true ]; then
		refresh_token=true
	else
		refresh_token=false
	fi
fi
command -v ssh >/dev/null 2>&1 || die "ssh is required"

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

bounded_ssh() {
	tmp=$(mktemp "${TMPDIR:-/tmp}/h100-offload-ssh.XXXXXX")
	status=0
	ssh -A -o BatchMode=yes -o ConnectTimeout=10 "$ssh_target" "$1" >"$tmp" 2>&1 &
	pid=$!
	elapsed=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$elapsed" -ge "$timeout" ]; then
			kill "$pid" 2>/dev/null || true
			sleep 1
			kill -9 "$pid" 2>/dev/null || true
			sed -n '1,120p' "$tmp"
			rm -f "$tmp"
			printf 'h100-offload-runner: timed out after %s seconds waiting for ssh target %s\n' "$timeout" "$ssh_target" >&2
			return 124
		fi
		sleep 1
		elapsed=$((elapsed + 1))
	done
	wait "$pid" || status=$?
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
	token_file_q=$(shell_quote "$remote_token_file")
	token_subject_q=$(shell_quote "$token_subject")
	token_audience_q=$(shell_quote "$token_audience")
	token_scope_q=$(shell_quote "$token_scope")
	token_ttl_q=$(shell_quote "$token_ttl")
	compose_q=$(shell_quote "$compose_file")
	compose_profile_q=$(shell_quote "$compose_profile")
	docker_socket_q=$(shell_quote "$docker_socket")
	set_services=
	for service in $services; do
		set_services="$set_services
set -- \"\$@\" $(shell_quote "$service")"
	done
	cat <<REMOTE
set -eu
command -v timeout >/dev/null 2>&1 || { echo 'missing timeout' >&2; exit 19; }
root=$root_q
model=$model_q
model_pattern=$model_pattern_q
image=$image_q
events_url=$events_q
timeout_seconds=$timeout
ensure_services=$ensure_services
compose_file=$compose_q
compose_profile=$compose_profile_q
docker_socket=$docker_socket_q
refresh_token=$refresh_token
token_file=$token_file_q
token_subject=$token_subject_q
token_audience=$token_audience_q
token_scope=$token_scope_q
token_ttl=$token_ttl_q
cd "\$root"
dirty=\$(timeout "\$timeout_seconds" git status --porcelain)
if [ -n "\$dirty" ]; then
	printf 'dirty remote checkout at %s\n' "\$root" >&2
	git status --short | sed -n '1,80p' >&2
	exit 20
fi
command -v docker >/dev/null 2>&1 || { echo 'missing docker' >&2; exit 21; }
timeout "\$timeout_seconds" docker image inspect "\$image" >/dev/null 2>&1 || { echo "missing worker image: \$image" >&2; exit 22; }
if [ "\$ensure_services" = true ]; then
	if [ "\$docker_socket" = auto ]; then
		case "\${DOCKER_HOST:-}" in
			unix://*) docker_socket=\${DOCKER_HOST#unix://} ;;
		esac
	fi
	if [ "\$docker_socket" = auto ] || [ -z "\$docker_socket" ]; then
		uid=\$(id -u)
		if [ -S "/run/user/\$uid/docker.sock" ]; then
			docker_socket=/run/user/\$uid/docker.sock
		elif [ -S /var/run/docker.sock ]; then
			docker_socket=/var/run/docker.sock
		else
			echo 'could not locate Docker socket for --ensure-services' >&2
			exit 26
		fi
	fi
	set --
$set_services
	BUS_DOCKER_SOCKET_HOST="\$docker_socket" timeout "\$timeout_seconds" docker compose -f "\$compose_file" --profile "\$compose_profile" up -d --no-deps "\$@" >/dev/null
fi
token_refreshed=false
if [ "\$refresh_token" = true ]; then
	case "\$token_file" in
		/*) ;;
		*) token_file="\$HOME/\$token_file" ;;
	esac
	token_dir=\$(dirname "\$token_file")
	mkdir -p "\$token_dir"
	tmp_token=\$(mktemp "\$token_dir/.api-token.XXXXXX")
	rm_token() { rm -f "\$tmp_token"; }
	trap rm_token EXIT INT TERM
	local_jwt_secret=\${BUS_AUTH_HS256_SECRET:-not-a-secret-local-development-hs256-key}
	if [ -x bus-operator-token/bin/bus-operator-token ]; then
		BUS_AUTH_HS256_SECRET="\$local_jwt_secret" timeout "\$timeout_seconds" ./bus-operator-token/bin/bus-operator-token --format token issue --local --subject "\$token_subject" --audience "\$token_audience" --scope "\$token_scope" --ttl "\$token_ttl" >"\$tmp_token"
	elif command -v go >/dev/null 2>&1 && [ -d bus-operator-token ]; then
		(cd bus-operator-token && BUS_AUTH_HS256_SECRET="\$local_jwt_secret" timeout "\$timeout_seconds" go run ./cmd/bus-operator-token --format token issue --local --subject "\$token_subject" --audience "\$token_audience" --scope "\$token_scope" --ttl "\$token_ttl") >"\$tmp_token"
	else
		echo 'remote host needs bus-operator-token/bin/bus-operator-token or go for token refresh' >&2
		exit 27
	fi
	if [ ! -s "\$tmp_token" ]; then
		echo 'remote token refresh produced an empty token file' >&2
		exit 28
	fi
	chmod 600 "\$tmp_token"
	mv "\$tmp_token" "\$token_file"
	trap - EXIT INT TERM
	token_refreshed=true
fi
command -v curl >/dev/null 2>&1 || { echo 'missing curl' >&2; exit 23; }
events_ready=false
events_waited=0
while [ "\$events_waited" -lt "\$timeout_seconds" ]; do
	if curl -fsS --max-time 2 "\$events_url/api/v1/events/capabilities" >/dev/null 2>&1; then
		events_ready=true
		break
	fi
	sleep 1
	events_waited=\$((events_waited + 1))
done
if [ "\$events_ready" != true ]; then
	echo "missing Events capabilities at \$events_url" >&2
	exit 24
fi
timeout "\$timeout_seconds" curl -fsS --max-time "\$timeout_seconds" http://127.0.0.1:11434/api/tags | grep -F "\$model_pattern" >/dev/null || { echo "missing Ollama model: \$model" >&2; exit 25; }
printf 'preflight ok: root=%s image=%s model=%s events=%s token_refreshed=%s token_file=%s\n' "\$root" "\$image" "\$model" "\$events_url" "\$token_refreshed" "\$token_file"
REMOTE
}

run_preflight() {
	printf 'h100-offload-runner: preflight target=%s root=%s model=%s image=%s ensure_services=%s refresh_token=%s\n' "$ssh_target" "$remote_root" "$model" "$image" "$ensure_services" "$refresh_token" >&2
	set +e
	output=$(bounded_ssh "$(remote_preflight_script)" 2>&1)
	status=$?
	set -e
	if [ "$status" -ne 0 ]; then
		printf 'h100-offload-runner: preflight failed target=%s root=%s timeout=%s status=%s ensure_services=%s refresh_token=%s\n' "$ssh_target" "$remote_root" "$timeout" "$status" "$ensure_services" "$refresh_token" >&2
		printf '%s\n' "$output" | sed 's/^/h100-offload-runner: remote: /' >&2
		return "$status"
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
