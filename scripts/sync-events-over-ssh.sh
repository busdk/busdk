#!/bin/sh
set -eu

# Moves Bus Events history between a local supervisor and a remote SSH host
# without requiring SSH port forwarding. This is a simple bootstrap sync helper:
# it uses bus-events export/import NDJSON over SSH. Cursored incremental sync
# remains product follow-up work in bus-events.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

SSH_TARGET=${BUS_EVENTS_SSH_SYNC_TARGET:-dev@ai.hg.fi}
REMOTE_ROOT=${BUS_EVENTS_SSH_SYNC_REMOTE_ROOT:-/home/dev/workspace/busdk/busdk}
LOCAL_API_URL=${BUS_EVENTS_SSH_SYNC_LOCAL_API_URL:-http://127.0.0.1:8081}
REMOTE_API_URL=${BUS_EVENTS_SSH_SYNC_REMOTE_API_URL:-http://127.0.0.1:8081}
LOCAL_TOKEN_FILE=${BUS_EVENTS_SSH_SYNC_LOCAL_TOKEN_FILE:-tmp/local-ai-platform/bus-config/auth/api-token}
REMOTE_TOKEN_FILE=${BUS_EVENTS_SSH_SYNC_REMOTE_TOKEN_FILE:-.config/bus/auth/api-token}
LOCAL_ENV_ID=${BUS_EVENTS_SSH_SYNC_LOCAL_ENV_ID:-env_local_supervisor}
LOCAL_ENV_NAME=${BUS_EVENTS_SSH_SYNC_LOCAL_ENV_NAME:-local-supervisor}
REMOTE_ENV_ID=${BUS_EVENTS_SSH_SYNC_REMOTE_ENV_ID:-env_h100_ai}
REMOTE_ENV_NAME=${BUS_EVENTS_SSH_SYNC_REMOTE_ENV_NAME:-h100-ai}
NAMES=${BUS_EVENTS_SSH_SYNC_NAMES:-}
DIRECTION=${BUS_EVENTS_SSH_SYNC_DIRECTION:-both}
KEEP_TEMP=${BUS_EVENTS_SSH_SYNC_KEEP_TEMP:-false}
REPEAT=${BUS_EVENTS_SSH_SYNC_REPEAT:-1}
INTERVAL_SECONDS=${BUS_EVENTS_SSH_SYNC_INTERVAL_SECONDS:-5}
SSH_WAIT_TIMEOUT=${BUS_EVENTS_SSH_SYNC_SSH_WAIT_TIMEOUT:-300}
ENSURE_H100_READINESS=${BUS_EVENTS_SSH_SYNC_ENSURE_H100_READINESS:-auto}

LOCAL_EVENTS_BIN=${BUS_EVENTS_SSH_SYNC_LOCAL_EVENTS_BIN:-$ROOT/bus-events/bin/bus-events}
REMOTE_TMP=${BUS_EVENTS_SSH_SYNC_REMOTE_TMP:-/tmp/bus-events-ssh-sync.ndjson}
REMOTE_GO_IMAGE=${BUS_EVENTS_SSH_SYNC_REMOTE_GO_IMAGE:-golang:1.26.3}
H100_RUNNER=${BUS_EVENTS_SSH_SYNC_H100_RUNNER:-$ROOT/scripts/h100-offload-runner.sh}
H100_COMPOSE_FILE=${BUS_EVENTS_SSH_SYNC_H100_COMPOSE_FILE:-compose.dev-task-docker.yaml}
H100_SERVICES=${BUS_EVENTS_SSH_SYNC_H100_SERVICES:-bus-events bus-integration-docker bus-integration-containers}
H100_DOCKER_SOCKET=${BUS_EVENTS_SSH_SYNC_H100_DOCKER_SOCKET:-auto}

usage() {
	cat >&2 <<'USAGE'
usage: sync-events-over-ssh.sh [options]

Options override compatibility BUS_EVENTS_SSH_SYNC_* environment variables.
Use flags for normal sync probes so the script can run through a stable
approved command prefix.

  --ssh-target USER@HOST         remote SSH target
  --remote-root DIR              remote BusDK checkout path
  --local-api-url URL            local Events API URL
  --remote-api-url URL           remote Events API URL
  --local-token-file FILE        local Events token file
  --remote-token-file FILE       remote Events token file
  --local-env-id ID              local environment technical id
  --local-env-name NAME          local environment display name
  --remote-env-id ID             remote environment technical id
  --remote-env-name NAME         remote environment display name
  --name EVENT_NAME              event name filter; may be repeated
  --direction DIR                both|local-to-remote|remote-to-local
  --repeat COUNT                 bounded sync iterations
  --interval-seconds SECONDS     delay between repeated sync iterations
  --ssh-wait-timeout SECONDS     SSH command timeout
  --ensure-h100-readiness[=BOOL] start H100 control-plane services and refresh
                                the remote token file before sync; auto by default
  --no-ensure-h100-readiness     disable H100 readiness automation
  --local-events-bin PATH        local bus-events binary
  --remote-tmp FILE              remote temporary NDJSON path
  --remote-go-image IMAGE        Go image fallback for remote export/import
  --h100-runner FILE             H100 readiness runner
  --h100-compose-file FILE       remote Compose file for H100 readiness
  --h100-services "A B ..."      remote services for H100 readiness
  --h100-docker-socket PATH|auto remote Docker socket for H100 readiness
  --keep-temp[=BOOL]             keep local temporary NDJSON files
USAGE
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		printf 'missing value for %s\n' "$1" >&2
		usage
		exit 2
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--ssh-target) need_arg "$@"; SSH_TARGET=$2; shift 2 ;;
		--remote-root) need_arg "$@"; REMOTE_ROOT=$2; shift 2 ;;
		--local-api-url) need_arg "$@"; LOCAL_API_URL=$2; shift 2 ;;
		--remote-api-url) need_arg "$@"; REMOTE_API_URL=$2; shift 2 ;;
		--local-token-file) need_arg "$@"; LOCAL_TOKEN_FILE=$2; shift 2 ;;
		--remote-token-file) need_arg "$@"; REMOTE_TOKEN_FILE=$2; shift 2 ;;
		--local-env-id) need_arg "$@"; LOCAL_ENV_ID=$2; shift 2 ;;
		--local-env-name) need_arg "$@"; LOCAL_ENV_NAME=$2; shift 2 ;;
		--remote-env-id) need_arg "$@"; REMOTE_ENV_ID=$2; shift 2 ;;
		--remote-env-name) need_arg "$@"; REMOTE_ENV_NAME=$2; shift 2 ;;
		--name) need_arg "$@"; NAMES="${NAMES:+$NAMES }$2"; shift 2 ;;
		--direction) need_arg "$@"; DIRECTION=$2; shift 2 ;;
		--repeat) need_arg "$@"; REPEAT=$2; shift 2 ;;
		--interval-seconds) need_arg "$@"; INTERVAL_SECONDS=$2; shift 2 ;;
		--ssh-wait-timeout) need_arg "$@"; SSH_WAIT_TIMEOUT=$2; shift 2 ;;
		--ensure-h100-readiness) ENSURE_H100_READINESS=true; shift ;;
		--ensure-h100-readiness=*) ENSURE_H100_READINESS=${1#*=}; shift ;;
		--no-ensure-h100-readiness) ENSURE_H100_READINESS=false; shift ;;
		--local-events-bin) need_arg "$@"; LOCAL_EVENTS_BIN=$2; shift 2 ;;
		--remote-tmp) need_arg "$@"; REMOTE_TMP=$2; shift 2 ;;
		--remote-go-image) need_arg "$@"; REMOTE_GO_IMAGE=$2; shift 2 ;;
		--h100-runner) need_arg "$@"; H100_RUNNER=$2; shift 2 ;;
		--h100-compose-file) need_arg "$@"; H100_COMPOSE_FILE=$2; shift 2 ;;
		--h100-services) need_arg "$@"; H100_SERVICES=$2; shift 2 ;;
		--h100-docker-socket) need_arg "$@"; H100_DOCKER_SOCKET=$2; shift 2 ;;
		--keep-temp) KEEP_TEMP=true; shift ;;
		--keep-temp=*) KEEP_TEMP=${1#*=}; shift ;;
		--no-keep-temp) KEEP_TEMP=false; shift ;;
		--help|-h) usage; exit 0 ;;
		*)
			printf 'unknown option: %s\n' "$1" >&2
			usage
			exit 2
			;;
	esac
done

case "$REMOTE_TOKEN_FILE" in
	/*) ;;
	*) REMOTE_TOKEN_FILE="/home/${SSH_TARGET%@*}/$REMOTE_TOKEN_FILE" ;;
esac

case "$DIRECTION" in
	both|local-to-remote|remote-to-local) ;;
	*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_DIRECTION=%s; expected both, local-to-remote, or remote-to-local\n' "$DIRECTION" >&2
		exit 2
		;;
esac

if [ ! -x "$LOCAL_EVENTS_BIN" ]; then
	printf 'local bus-events binary not found: %s\n' "$LOCAL_EVENTS_BIN" >&2
	exit 2
fi

if [ ! -s "$LOCAL_TOKEN_FILE" ]; then
	printf 'local token file missing or empty: %s\n' "$LOCAL_TOKEN_FILE" >&2
	exit 2
fi

case "$KEEP_TEMP" in
	true|1|yes|on|false|0|no|off|'') ;;
	*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_KEEP_TEMP=%s\n' "$KEEP_TEMP" >&2
		exit 2
		;;
esac

case "$ENSURE_H100_READINESS" in
	auto|true|1|yes|on|false|0|no|off) ;;
	*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_ENSURE_H100_READINESS=%s\n' "$ENSURE_H100_READINESS" >&2
		exit 2
		;;
esac

case "$REPEAT" in
	''|*[!0-9]*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_REPEAT=%s; expected a positive integer\n' "$REPEAT" >&2
		exit 2
		;;
	0)
		printf 'invalid BUS_EVENTS_SSH_SYNC_REPEAT=0; use a positive integer for bounded sync runs\n' >&2
		exit 2
		;;
esac

case "$INTERVAL_SECONDS" in
	''|*[!0-9]*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_INTERVAL_SECONDS=%s; expected a non-negative integer\n' "$INTERVAL_SECONDS" >&2
		exit 2
		;;
esac

case "$SSH_WAIT_TIMEOUT" in
	''|*[!0-9]*)
		printf 'invalid BUS_EVENTS_SSH_SYNC_SSH_WAIT_TIMEOUT=%s; expected a positive integer\n' "$SSH_WAIT_TIMEOUT" >&2
		exit 2
		;;
	0)
		printf 'invalid BUS_EVENTS_SSH_SYNC_SSH_WAIT_TIMEOUT=0; use a positive integer\n' >&2
		exit 2
		;;
esac

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

should_ensure_h100_readiness() {
	case "$ENSURE_H100_READINESS" in
		true|1|yes|on) return 0 ;;
		false|0|no|off) return 1 ;;
	esac
	case "$SSH_TARGET $REMOTE_ROOT $REMOTE_ENV_ID $REMOTE_ENV_NAME" in
		*[Hh]100*|*ai.hg.fi*) return 0 ;;
		*) return 1 ;;
	esac
}

ensure_h100_readiness() {
	if ! should_ensure_h100_readiness; then
		return 0
	fi
	if [ ! -x "$H100_RUNNER" ]; then
		printf 'H100 readiness runner is not executable: %s\n' "$H100_RUNNER" >&2
		exit 2
	fi
	"$H100_RUNNER" \
		--mode preflight \
		--ssh-target "$SSH_TARGET" \
		--remote-root "$REMOTE_ROOT" \
		--events-url "$REMOTE_API_URL" \
		--timeout "$SSH_WAIT_TIMEOUT" \
		--ensure-services \
		--refresh-token \
		--remote-token-file "$REMOTE_TOKEN_FILE" \
		--compose-file "$H100_COMPOSE_FILE" \
		--services "$H100_SERVICES" \
		--docker-socket "$H100_DOCKER_SOCKET" >/dev/null
	printf 'h100-readiness ok: target=%s remote_token_file=%s services=%s\n' "$SSH_TARGET" "$REMOTE_TOKEN_FILE" "$H100_SERVICES" >&2
}

ensure_h100_readiness

local_to_remote=$(mktemp "${TMPDIR:-/tmp}/bus-events-local-to-remote.XXXXXX")
remote_to_local=$(mktemp "${TMPDIR:-/tmp}/bus-events-remote-to-local.XXXXXX")
cleanup() {
	case "$KEEP_TEMP" in
		true|1|yes|on)
			printf 'kept local sync files: %s %s\n' "$local_to_remote" "$remote_to_local" >&2
			;;
		*)
			rm -f "$local_to_remote" "$remote_to_local"
			;;
	esac
}
trap cleanup EXIT INT TERM

local_export() {
	set -- "$LOCAL_EVENTS_BIN" --api-url "$LOCAL_API_URL" --token-file "$LOCAL_TOKEN_FILE" -o "$local_to_remote" export
	for name in $NAMES; do
		set -- "$@" --name "$name"
	done
	set -- "$@" --environment-id "$LOCAL_ENV_ID" --environment-name "$LOCAL_ENV_NAME"
	"$@"
}

local_import() {
	set -- "$LOCAL_EVENTS_BIN" --api-url "$LOCAL_API_URL" --token-file "$LOCAL_TOKEN_FILE" import \
		--input "$remote_to_local" \
		--environment-id "$REMOTE_ENV_ID" \
		--environment-name "$REMOTE_ENV_NAME"
	"$@"
}

remote_run() {
	in=$(mktemp "${TMPDIR:-/tmp}/bus-events-ssh-run-in.XXXXXX")
	cat > "$in"
	status=0
	run_ssh_with_input "$in" sh -s || status=$?
	rm -f "$in"
	return "$status"
}

run_ssh_with_input() {
	input_file=$1
	shift
	out=$(mktemp "${TMPDIR:-/tmp}/bus-events-ssh-out.XXXXXX")
	err=$(mktemp "${TMPDIR:-/tmp}/bus-events-ssh-err.XXXXXX")
	ssh -A -o BatchMode=yes -o ConnectTimeout=20 "$SSH_TARGET" "$@" < "$input_file" >"$out" 2>"$err" &
	pid=$!
	elapsed=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$elapsed" -ge "$SSH_WAIT_TIMEOUT" ]; then
			kill "$pid" 2>/dev/null || true
			sleep 1
			kill -9 "$pid" 2>/dev/null || true
			cat "$out"
			cat "$err" >&2
			rm -f "$out" "$err"
			printf 'timed out after %s seconds waiting for ssh target %s\n' "$SSH_WAIT_TIMEOUT" "$SSH_TARGET" >&2
			return 124
		fi
		sleep 1
		elapsed=$((elapsed + 1))
	done
	status=0
	wait "$pid" || status=$?
	cat "$out"
	cat "$err" >&2
	rm -f "$out" "$err"
	return "$status"
}

remote_import_script() {
	cat <<REMOTE
set -eu
if [ ! -s '$REMOTE_TOKEN_FILE' ]; then
	printf 'remote token file missing or empty: %s\n' '$REMOTE_TOKEN_FILE' >&2
	exit 2
fi
cd '$REMOTE_ROOT'
if [ -x bus-events/bin/bus-events ]; then
	bus_events_cmd='./bus-events/bin/bus-events'
	cd '$REMOTE_ROOT'
	"\$bus_events_cmd" --api-url '$REMOTE_API_URL' --token-file '$REMOTE_TOKEN_FILE' import --input '$REMOTE_TMP' --environment-id '$LOCAL_ENV_ID' --environment-name '$LOCAL_ENV_NAME'
elif command -v go >/dev/null 2>&1; then
	cd '$REMOTE_ROOT/bus-events'
	go run ./cmd/bus-events --api-url '$REMOTE_API_URL' --token-file '$REMOTE_TOKEN_FILE' import --input '$REMOTE_TMP' --environment-id '$LOCAL_ENV_ID' --environment-name '$LOCAL_ENV_NAME'
elif command -v docker >/dev/null 2>&1; then
	cd '$REMOTE_ROOT'
	remote_token_dir=\$(dirname '$REMOTE_TOKEN_FILE')
	docker run --rm --network host -v '$REMOTE_ROOT':/workspace -v /tmp:/tmp -v "\$remote_token_dir":"\$remote_token_dir":ro -w /workspace/bus-events '$REMOTE_GO_IMAGE' go run ./cmd/bus-events --api-url '$REMOTE_API_URL' --token-file '$REMOTE_TOKEN_FILE' import --input '$REMOTE_TMP' --environment-id '$LOCAL_ENV_ID' --environment-name '$LOCAL_ENV_NAME'
else
	printf 'remote host needs bus-events/bin/bus-events, go, or docker for Events import\n' >&2
	exit 2
fi
REMOTE
}

remote_export_script() {
	cat <<REMOTE
set -eu
if [ ! -s '$REMOTE_TOKEN_FILE' ]; then
	printf 'remote token file missing or empty: %s\n' '$REMOTE_TOKEN_FILE' >&2
	exit 2
fi
cd '$REMOTE_ROOT'
set -- --api-url '$REMOTE_API_URL' --token-file '$REMOTE_TOKEN_FILE' -o '$REMOTE_TMP' export
for name in $NAMES; do
	set -- "\$@" --name "\$name"
done
set -- "\$@" --environment-id '$REMOTE_ENV_ID' --environment-name '$REMOTE_ENV_NAME'
if [ -x bus-events/bin/bus-events ]; then
	./bus-events/bin/bus-events "\$@"
elif command -v go >/dev/null 2>&1; then
	cd '$REMOTE_ROOT/bus-events'
	go run ./cmd/bus-events "\$@"
elif command -v docker >/dev/null 2>&1; then
	cd '$REMOTE_ROOT'
	remote_token_dir=\$(dirname '$REMOTE_TOKEN_FILE')
	docker run --rm --network host -v '$REMOTE_ROOT':/workspace -v /tmp:/tmp -v "\$remote_token_dir":"\$remote_token_dir":ro -w /workspace/bus-events '$REMOTE_GO_IMAGE' go run ./cmd/bus-events "\$@"
else
	printf 'remote host needs bus-events/bin/bus-events, go, or docker for Events export\n' >&2
	exit 2
fi
REMOTE
}

remote_put() {
	remote_tmp_q=$(shell_quote "$REMOTE_TMP")
	run_ssh_with_input "$local_to_remote" "cat > $remote_tmp_q"
}

remote_get() {
	remote_tmp_q=$(shell_quote "$REMOTE_TMP")
	run_ssh_with_input /dev/null "cat $remote_tmp_q" > "$remote_to_local"
}

sync_once() {
	case "$DIRECTION" in
		both|local-to-remote)
		local_export
		remote_put
		remote_import_script | remote_run
		printf 'local-to-remote events=%s\n' "$(wc -l < "$local_to_remote" | tr -d ' ')"
		;;
	esac

	case "$DIRECTION" in
		both|remote-to-local)
		remote_export_script | remote_run
		remote_get
		local_import
		printf 'remote-to-local events=%s\n' "$(wc -l < "$remote_to_local" | tr -d ' ')"
		;;
	esac
}

run_index=1
while [ "$run_index" -le "$REPEAT" ]; do
	if [ "$REPEAT" -gt 1 ]; then
		printf 'sync run %s/%s\n' "$run_index" "$REPEAT" >&2
	fi
	sync_once
	if [ "$run_index" -lt "$REPEAT" ] && [ "$INTERVAL_SECONDS" -gt 0 ]; then
		sleep "$INTERVAL_SECONDS"
	fi
	run_index=$((run_index + 1))
done
