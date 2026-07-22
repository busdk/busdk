#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/tests/superproject/test_credential_continuity_short_ttl_e2e.sh"

MODE=""
MODULE_SOURCE_ROOT=""
MODULE_REPO_ROOT=""
BUSDK_REF="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)"
BUS_SERVICES_REF=""
BUS_INTEGRATION_SERVICES_REF=""
BUS_IDENTITIES_REF=""
BUS_API_REF=""
BUS_API_PROVIDER_EVENTS_REF=""
EVENTS_BACKEND=""
TTL=""
RENEW_BEFORE=""
ROTATIONS=""
RESULT_DIR=""
BUS_HOST="127.0.0.7"
PREFLIGHT_ONLY=0

RESULT_ABS=""
RUNTIME_DIR=""
SOURCE_DIR=""
STACK_DIR=""
STATE_DIR=""
BIN_DIR=""
TOKEN_FILE=""
EVENTS_URL=""
API_URL=""
PG_BIN=""
PG_SOCKET_DIR=""
SUBSCRIPTION_PID=""
STACK_STARTED=0
FINAL_STATUS="failed"
FAILURE_REASON=""

usage() {
  cat <<'EOF'
Usage:
  test_credential_continuity_short_ttl_e2e.sh --mode parent-fail|candidate-pass \
    --module-source-root DIR --module-repo-root DIR [--busdk-ref SHA] \
    --bus-services-ref SHA --bus-integration-services-ref SHA \
    --bus-identities-ref SHA --bus-api-ref SHA \
    --bus-api-provider-events-ref SHA --events-backend postgres \
    --ttl 12s --renew-before 6s --rotations 2 --result-dir DIR \
    [--host LOOPBACK] [--preflight-only]

The harness builds an exact source closure, starts ordinary nonforeground Bus
Services on an isolated loopback with native PostgreSQL, kills only the renewal
controller, exercises ordinary-up reattachment without changing healthy child
PIDs, observes two atomic credential rotations, and probes Thread, Worker,
Repos, and an already-open Events subscription after each rotation. Token
contents are never recorded.
EOF
}

die() {
  FAILURE_REASON="$1"
  printf 'ERROR: %s\n' "$1" >&2
  if [[ -n "$RESULT_ABS" && -d "$RESULT_ABS" ]]; then
    printf '%s\n' "$1" >"$RESULT_ABS/failure.txt"
  fi
  exit 1
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || die "missing value for $option"
}

while (($# > 0)); do
  case "$1" in
    --mode) require_value "$1" "${2:-}"; MODE="$2"; shift 2 ;;
    --module-source-root) require_value "$1" "${2:-}"; MODULE_SOURCE_ROOT="$2"; shift 2 ;;
    --module-repo-root) require_value "$1" "${2:-}"; MODULE_REPO_ROOT="$2"; shift 2 ;;
    --busdk-ref) require_value "$1" "${2:-}"; BUSDK_REF="$2"; shift 2 ;;
    --bus-services-ref) require_value "$1" "${2:-}"; BUS_SERVICES_REF="$2"; shift 2 ;;
    --bus-integration-services-ref) require_value "$1" "${2:-}"; BUS_INTEGRATION_SERVICES_REF="$2"; shift 2 ;;
    --bus-identities-ref) require_value "$1" "${2:-}"; BUS_IDENTITIES_REF="$2"; shift 2 ;;
    --bus-api-ref) require_value "$1" "${2:-}"; BUS_API_REF="$2"; shift 2 ;;
    --bus-api-provider-events-ref) require_value "$1" "${2:-}"; BUS_API_PROVIDER_EVENTS_REF="$2"; shift 2 ;;
    --events-backend) require_value "$1" "${2:-}"; EVENTS_BACKEND="$2"; shift 2 ;;
    --ttl) require_value "$1" "${2:-}"; TTL="$2"; shift 2 ;;
    --renew-before) require_value "$1" "${2:-}"; RENEW_BEFORE="$2"; shift 2 ;;
    --rotations) require_value "$1" "${2:-}"; ROTATIONS="$2"; shift 2 ;;
    --result-dir) require_value "$1" "${2:-}"; RESULT_DIR="$2"; shift 2 ;;
    --host) require_value "$1" "${2:-}"; BUS_HOST="$2"; shift 2 ;;
    --preflight-only) PREFLIGHT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$MODE" == "parent-fail" || "$MODE" == "candidate-pass" ]] || die "--mode must be parent-fail or candidate-pass"
[[ "$EVENTS_BACKEND" == "postgres" ]] || die "--events-backend must be postgres"
[[ "$TTL" =~ ^[0-9]+s$ ]] || die "--ttl must be a positive whole-second duration"
[[ "$RENEW_BEFORE" =~ ^[0-9]+s$ ]] || die "--renew-before must be a positive whole-second duration"
[[ "$ROTATIONS" == "2" ]] || die "--rotations must be exactly 2"
TTL_SECONDS="${TTL%s}"
RENEW_SECONDS="${RENEW_BEFORE%s}"
((TTL_SECONDS > 0)) || die "--ttl must be greater than zero"
((RENEW_SECONDS > 0 && RENEW_SECONDS < TTL_SECONDS)) || die "--renew-before must be greater than zero and less than --ttl"

for required in MODULE_SOURCE_ROOT MODULE_REPO_ROOT BUSDK_REF BUS_SERVICES_REF \
  BUS_INTEGRATION_SERVICES_REF BUS_IDENTITIES_REF BUS_API_REF \
  BUS_API_PROVIDER_EVENTS_REF RESULT_DIR; do
  [[ -n "${!required}" ]] || die "missing required argument for $required"
done

MODULE_SOURCE_ROOT="$(cd "$MODULE_SOURCE_ROOT" 2>/dev/null && pwd)" || die "module source root is unavailable"
MODULE_REPO_ROOT="$(cd "$MODULE_REPO_ROOT" 2>/dev/null && pwd)" || die "module repository root is unavailable"
if [[ "$RESULT_DIR" = /* ]]; then
  RESULT_ABS="$RESULT_DIR"
else
  RESULT_ABS="$ROOT_DIR/$RESULT_DIR"
fi

command -v git >/dev/null || die "git is required"
command -v go >/dev/null || die "go is required"
command -v jq >/dev/null || die "jq is required"
command -v python3 >/dev/null || die "python3 is required"
command -v timeout >/dev/null || die "timeout is required"
command -v tar >/dev/null || die "tar is required"
command -v sha256sum >/dev/null || die "sha256sum is required"

TOP_LEVEL="$(git -C "$ROOT_DIR" rev-parse --show-toplevel)"
[[ "$TOP_LEVEL" == "$ROOT_DIR" ]] || die "Git top-level does not match harness root"
[[ "$(git -C "$ROOT_DIR" rev-parse "$BUSDK_REF^{commit}")" == "$BUSDK_REF" ]] || die "BusDK ref is not an exact full commit"
[[ -d "$ROOT_DIR/tests/superproject" && -f "$SCRIPT_PATH" ]] || die "target tests/superproject harness path is unavailable"
GIT_DIR="$(git -C "$ROOT_DIR" rev-parse --git-dir)"
[[ -w "$GIT_DIR" ]] || die "Git metadata is not writable"
ROOT_HEAD="$(git -C "$ROOT_DIR" rev-parse HEAD)"
ROOT_TREE="$(git -C "$ROOT_DIR" rev-parse 'HEAD^{tree}')"
HARNESS_PATH="${SCRIPT_PATH#"$ROOT_DIR"/}"
[[ -z "$(git -C "$ROOT_DIR" status --short --untracked-files=all -- "$HARNESS_PATH")" ]] || die "tracked harness bytes differ from HEAD"
HARNESS_SHA256="$(sha256sum "$SCRIPT_PATH" | awk '{print $1}')"

mapfile -t DIRTY_PATHS < <(git -C "$ROOT_DIR" status --short --untracked-files=all | sed -E 's/^...//')
for dirty_path in "${DIRTY_PATHS[@]}"; do
  die "integration worktree has unrelated dirt: $dirty_path"
done

find_pg_bin() {
  local candidate
  if command -v postgres >/dev/null 2>&1; then
    candidate="$(dirname "$(command -v postgres)")"
    [[ -x "$candidate/initdb" && -x "$candidate/pg_ctl" && -x "$candidate/pg_isready" ]] && { printf '%s\n' "$candidate"; return; }
  fi
  for candidate in /usr/lib/postgresql/*/bin /opt/homebrew/opt/postgresql@*/bin /opt/homebrew/opt/postgresql/bin /usr/local/opt/postgresql@*/bin /usr/local/opt/postgresql/bin; do
    [[ -x "$candidate/postgres" && -x "$candidate/initdb" && -x "$candidate/pg_ctl" && -x "$candidate/pg_isready" ]] || continue
    printf '%s\n' "$candidate"
    return
  done
  return 1
}

PG_BIN="$(find_pg_bin)" || die "native PostgreSQL initdb/postgres/pg_ctl/pg_isready are required"

declare -A OVERRIDE_REFS=(
  [bus-services]="$BUS_SERVICES_REF"
  [bus-integration-services]="$BUS_INTEGRATION_SERVICES_REF"
  [bus-identities]="$BUS_IDENTITIES_REF"
  [bus-api]="$BUS_API_REF"
  [bus-api-provider-events]="$BUS_API_PROVIDER_EVENTS_REF"
)

module_pin() {
  local module="$1"
  local pin
  pin="$(git -C "$ROOT_DIR" ls-tree "$BUSDK_REF" -- "$module" | awk '$1 == "160000" {print $3}')"
  [[ -n "$pin" ]] || die "BusDK ref does not pin required module $module"
  printf '%s\n' "$pin"
}

module_repo_for_ref() {
  local module="$1"
  local ref="$2"
  local candidate
  for candidate in "$MODULE_SOURCE_ROOT/$module" "$MODULE_REPO_ROOT/$module"; do
    [[ -d "$candidate" ]] || continue
    if git -C "$candidate" cat-file -e "$ref^{commit}" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

for module in bus-services bus-integration-services bus-identities bus-api bus-api-provider-events; do
  ref="${OVERRIDE_REFS[$module]}"
  repo="$(module_repo_for_ref "$module" "$ref")" || die "required ref $module@$ref is unavailable"
  [[ "$(git -C "$repo" rev-parse "$ref^{commit}")" == "$ref" ]] || die "$module ref is not an exact full commit: $ref"
done

RESULT_PARENT="$(dirname "$RESULT_ABS")"
mkdir -p "$RESULT_PARENT"
PREFLIGHT_SENTINEL="$RESULT_PARENT/.thread131-preflight-$$"
: >"$PREFLIGHT_SENTINEL"
rm -f "$PREFLIGHT_SENTINEL"

python3 - "$BUS_HOST" <<'PY'
import ipaddress
import socket
import sys

host = sys.argv[1]
address = ipaddress.ip_address(host)
if not address.is_loopback:
    raise SystemExit("harness host must be loopback")
for port in (5432, 8081, 8090, 8091):
    sock = socket.socket()
    try:
        sock.bind((host, port))
    except OSError as exc:
        raise SystemExit(f"loopback prerequisite failed for {host}:{port}: {exc}")
    finally:
        sock.close()
PY

printf 'preflight root=%s\n' "$ROOT_DIR"
printf 'preflight head=%s\n' "$ROOT_HEAD"
printf 'preflight tree=%s\n' "$ROOT_TREE"
printf 'preflight harness_sha256=%s\n' "$HARNESS_SHA256"
printf 'preflight git_dir=%s\n' "$GIT_DIR"
printf 'preflight postgres_bin=%s\n' "$PG_BIN"
printf 'preflight result_root=%s\n' "$RESULT_ABS"
printf 'preflight loopback=%s\n' "$BUS_HOST"
printf 'preflight status=pass\n'
((PREFLIGHT_ONLY == 0)) || exit 0

[[ ! -e "$RESULT_ABS" ]] || die "result directory already exists: $RESULT_ABS"
mkdir -p "$RESULT_ABS"
RUNTIME_DIR="$RESULT_ABS/runtime"
SOURCE_DIR="$RUNTIME_DIR/source"
STACK_DIR="$RUNTIME_DIR/stack"
STATE_DIR="$STACK_DIR/.bus/services"
BIN_DIR="$STACK_DIR/bin"
TOKEN_FILE="$STACK_DIR/.bus/tokens/local-events.jwt"
EVENTS_URL="http://$BUS_HOST:8081/local/v1"
API_URL="http://$BUS_HOST:8090/local/v1"
mkdir -p "$SOURCE_DIR" "$STACK_DIR" "$BIN_DIR" "$RUNTIME_DIR/cache/go-build" "$RUNTIME_DIR/cache/go-mod" "$RUNTIME_DIR/go-tmp" "$RESULT_ABS/operations"

printf 'mode\t%s\nstarted_at\t%s\nbusdk\t%s\nroot_head\t%s\nroot_tree\t%s\nharness_sha256\t%s\nhost\t%s\nttl\t%s\nrenew_before\t%s\nrotations\t%s\n' \
  "$MODE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BUSDK_REF" "$ROOT_HEAD" "$ROOT_TREE" "$HARNESS_SHA256" "$BUS_HOST" "$TTL" "$RENEW_BEFORE" "$ROTATIONS" >"$RESULT_ABS/run.tsv"
: >"$RESULT_ABS/commands.log"
: >"$RESULT_ABS/exits.tsv"
: >"$RESULT_ABS/timings.tsv"
: >"$RESULT_ABS/refs.tsv"
: >"$RESULT_ABS/rotations.tsv"

record_command() {
  local label="$1"
  shift
  {
    printf '%s\t' "$label"
    printf '%q ' "$@"
    printf '\n'
  } >>"$RESULT_ABS/commands.log"
}

run_capture_with_timeout() {
  local label="$1"
  local wait_bound="$2"
  shift 2
  local start end rc
  start="$(date +%s%N)"
  record_command "$label" "$@"
  set +e
  timeout "$wait_bound" "$@" >"$RESULT_ABS/operations/$label.stdout" 2>"$RESULT_ABS/operations/$label.stderr"
  rc=$?
  set -e
  end="$(date +%s%N)"
  printf '%s\t%s\n' "$label" "$rc" >>"$RESULT_ABS/exits.tsv"
  printf '%s\t%s\t%s\n' "$label" "$start" "$end" >>"$RESULT_ABS/timings.tsv"
  if ((rc != 0)); then
    if grep -Eqi 'HTTP[^[:cntrl:]]*(401|403)|API returned[[:space:]]+(401|403)|401 Unauthorized|403 Forbidden|invalid_token|insufficient_access|invalid api key' "$RESULT_ABS/operations/$label.stderr" "$RESULT_ABS/operations/$label.stdout"; then
      printf '%s\tcredential_failure\n' "$label" >>"$RESULT_ABS/http-audit.tsv"
    fi
    die "$label failed with exit $rc"
  fi
}

run_capture() {
  local label="$1"
  shift
  run_capture_with_timeout "$label" 30s "$@"
}

owned_pid_running() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

capture_pids() {
  local destination="$1"
  local service pid
  : >"$destination"
  pid="$(tr -d '[:space:]' <"$STATE_DIR/bus-integration-services.pid")"
  printf 'serve\t%s\n' "$pid" >>"$destination"
  for service in postgres identities events repos workers threads api; do
    pid="$(jq -r '.pid // empty' "$STATE_DIR/$service.json")"
    [[ "$pid" =~ ^[0-9]+$ ]] || die "missing process identity for $service"
    printf '%s\t%s\n' "$service" "$pid" >>"$destination"
  done
  if [[ -n "$SUBSCRIPTION_PID" ]]; then
    printf 'subscription\t%s\n' "$SUBSCRIPTION_PID" >>"$destination"
  fi
}

assert_baseline_pids_owned() {
  local pidfile="$1"
  local name pid state
  while IFS=$'\t' read -r name pid; do
    [[ "$name" == "subscription" ]] && continue
    if [[ "$name" == "serve" ]]; then
      # The controller ("serve") is identified by the cmdline/--state-dir
      # domain via owned_controller_pids, never by the child env-marker
      # domain that attempt_pid_identity_state applies below: it is not
      # launched with a BUS_SERVICES_BUS_DIR/PGDATA marker of its own, so
      # running it through the child identity check false-RED's a live,
      # correctly owned controller.
      local -a controller_owners=()
      mapfile -t controller_owners < <(owned_controller_pids)
      [[ "$pid" =~ ^[0-9]+$ ]] && owned_pid_active "$pid" &&
        ((${#controller_owners[@]} == 1)) && [[ "${controller_owners[0]}" == "$pid" ]] ||
        die "baseline ownership check failed: serve pid=$pid not sole controller owner (owners: ${controller_owners[*]:-none})"
      continue
    fi
    state="$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")"
    [[ "$state" == "owned" ]] || die "baseline ownership check failed: $name pid=$pid classified $state, expected owned"
  done <"$pidfile"
}

assert_same_pids() {
  local expected="$1"
  local observed="$2"
  local name pid observed_pid
  while IFS=$'\t' read -r name pid; do
    observed_pid="$(awk -F '\t' -v name="$name" '$1 == name {print $2}' "$observed")"
    [[ "$observed_pid" == "$pid" ]] || die "$name process identity changed: $pid -> ${observed_pid:-missing}"
    owned_pid_running "$pid" || die "$name process $pid is not running"
  done <"$expected"
}

owned_pid_active() {
  local pid="$1"
  local body rest state
  owned_pid_running "$pid" || return 1
  [[ -r "/proc/$pid/stat" ]] || return 0
  body="$(<"/proc/$pid/stat")"
  rest="${body##*) }"
  state="${rest%% *}"
  [[ "$state" != "Z" ]]
}

owned_controller_pids() {
  python3 - "$BIN_DIR/bus-integration-services" "$STATE_DIR" <<'PY'
import os
import pathlib
import sys

expected_executable = os.path.realpath(sys.argv[1])
expected_state = os.path.realpath(sys.argv[2])
owners = []
for entry in pathlib.Path("/proc").iterdir():
    if not entry.name.isdigit():
        continue
    try:
        raw = (entry / "cmdline").read_bytes()
        executable = os.path.realpath(os.readlink(entry / "exe"))
    except (FileNotFoundError, PermissionError, ProcessLookupError, OSError):
        continue
    args = raw.rstrip(b"\0").split(b"\0") if raw else []
    try:
        decoded = [part.decode() for part in args]
    except UnicodeDecodeError:
        continue
    if executable != expected_executable or "serve" not in decoded:
        continue
    state_dir = ""
    for index, arg in enumerate(decoded):
        if arg == "--state-dir" and index + 1 < len(decoded):
            state_dir = decoded[index + 1]
        elif arg.startswith("--state-dir="):
            state_dir = arg.split("=", 1)[1]
    if state_dir and os.path.realpath(state_dir) == expected_state:
        owners.append(int(entry.name))
for pid in sorted(owners):
    print(pid)
PY
}

wait_for_controller_exit() {
  local pid="$1"
  local deadline=$((SECONDS + 10))
  while ((SECONDS < deadline)); do
    owned_pid_active "$pid" || return 0
    sleep 0.05
  done
  return 1
}

wait_for_replacement_owner() {
  local old_pid="$1"
  local deadline=$((SECONDS + 20))
  local published_pid
  local -a owners=()
  REPLACEMENT_OWNER_PID=""
  while ((SECONDS < deadline)); do
    published_pid="$(tr -d '[:space:]' <"$STATE_DIR/bus-integration-services.pid" 2>/dev/null || true)"
    mapfile -t owners < <(owned_controller_pids)
    if [[ "$published_pid" =~ ^[0-9]+$ && "$published_pid" != "$old_pid" ]] &&
      owned_pid_active "$published_pid" && ((${#owners[@]} == 1)) && [[ "${owners[0]}" == "$published_pid" ]]; then
      REPLACEMENT_OWNER_PID="$published_pid"
      return 0
    fi
    sleep 0.05
  done
  return 1
}

child_pids_match() {
  local expected="$1"
  local observed="$2"
  local name pid observed_pid
  while IFS=$'\t' read -r name pid; do
    [[ "$name" == "serve" || "$name" == "subscription" ]] && continue
    observed_pid="$(awk -F '\t' -v name="$name" '$1 == name {print $2}' "$observed")"
    [[ "$observed_pid" == "$pid" ]] || return 1
    owned_pid_active "$pid" || return 1
  done <"$expected"
}

audit_retained_artifacts() {
  local http_status="clean"
  local secret_status="clean"
  local -a audit_files=()
  mapfile -d '' -t audit_files < <(
    find "$RESULT_ABS/operations" -type f -print0
    if [[ -d "$STATE_DIR" ]]; then
      find "$STATE_DIR" -type f \( -name '*.log' -o -name '*.stdout' -o -name '*.stderr' \) -print0
    fi
    find "$RESULT_ABS" -maxdepth 1 -type f \( -name '*.tsv' -o -name '*.txt' -o -name '*.log' -o -name '*.ndjson' -o -name '*.stdout' -o -name '*.stderr' \) -print0
  )
  if grep -Eqi -- 'HTTP[^[:cntrl:]]*(401|403)|API returned[[:space:]]+(401|403)|401 Unauthorized|403 Forbidden|invalid_token|insufficient_access|invalid api key' "${audit_files[@]}"; then
    http_status="found"
  fi
  if grep -Eq -- 'Authorization:[[:space:]]*Bearer|BUS_API_JWT_SECRET|BUS_AUTH_HS256_SECRET|(^|[^[:alnum:]_-])[[:alnum:]_-]{10,}\.[[:alnum:]_-]{10,}\.[[:alnum:]_-]{10,}([^[:alnum:]_-]|$)' "${audit_files[@]}"; then
    secret_status="found"
  fi
  printf 'credential_http\t%s\nsecret_leak\t%s\n' "$http_status" "$secret_status" >"$RESULT_ABS/audit.tsv"
  [[ "$http_status" == "clean" && "$secret_status" == "clean" ]]
}

verify_retained_repositories() {
  local require_all="${1:-0}"
  local label timestamp repo_id repo_path
  local count=0
  local initial_seen=0
  local rotation_1_seen=0
  local rotation_2_seen=0
  if [[ ! -f "$RESULT_ABS/repos-materialization.tsv" ]]; then
    ((require_all == 0))
    return
  fi
  while IFS=$'\t' read -r label timestamp repo_id repo_path; do
    case "$label:$repo_id" in
      initial:product) initial_seen=1 ;;
      rotation-1:thread131-rotation-1) rotation_1_seen=1 ;;
      rotation-2:thread131-rotation-2) rotation_2_seen=1 ;;
      *) return 1 ;;
    esac
    [[ -n "$timestamp" && -f "$repo_path/HEAD" ]] || return 1
    [[ "$(git --git-dir="$repo_path" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]] || return 1
    count=$((count + 1))
  done <"$RESULT_ABS/repos-materialization.tsv"
  if ((require_all == 1)); then
    ((count == 3 && initial_seen == 1 && rotation_1_seen == 1 && rotation_2_seen == 1))
  fi
}

owned_attempt_pids() {
  local bin_dir="$1"
  local pg_bin="$2"
  local stack_dir="$3"
  python3 - "$bin_dir" "$pg_bin" "$stack_dir" <<'PY'
import os
import pathlib
import sys

bin_dir = os.path.realpath(sys.argv[1])
pg_executable = os.path.realpath(os.path.join(sys.argv[2], "postgres"))
stack_dir = os.path.realpath(sys.argv[3])
bus_dir_marker = ("BUS_SERVICES_BUS_DIR=" + stack_dir + "/.bus").encode()
pgdata_marker = ("PGDATA=" + stack_dir + "/postgres/data").encode()

owners = []
for entry in pathlib.Path("/proc").iterdir():
    if not entry.name.isdigit():
        continue
    try:
        executable = os.path.realpath(os.readlink(entry / "exe"))
        environ = (entry / "environ").read_bytes()
    except (FileNotFoundError, PermissionError, ProcessLookupError, OSError):
        continue
    fields = set(environ.split(b"\0"))
    if executable == pg_executable:
        if pgdata_marker in fields:
            owners.append((int(entry.name), executable, "pgdata"))
        continue
    if os.path.dirname(executable) == bin_dir and bus_dir_marker in fields:
        owners.append((int(entry.name), executable, "bus_dir"))
for pid, executable, marker in sorted(owners):
    print(f"{pid}\t{executable}\t{marker}")
PY
}

attempt_pid_still_owned() {
  local pid="$1"
  local bin_dir="$2"
  local pg_bin="$3"
  local stack_dir="$4"
  python3 - "$pid" "$bin_dir" "$pg_bin" "$stack_dir" <<'PY'
import os
import sys

pid = sys.argv[1]
bin_dir = os.path.realpath(sys.argv[2])
pg_executable = os.path.realpath(os.path.join(sys.argv[3], "postgres"))
stack_dir = os.path.realpath(sys.argv[4])
bus_dir_marker = ("BUS_SERVICES_BUS_DIR=" + stack_dir + "/.bus").encode()
pgdata_marker = ("PGDATA=" + stack_dir + "/postgres/data").encode()

try:
    executable = os.path.realpath(os.readlink(f"/proc/{pid}/exe"))
    environ = open(f"/proc/{pid}/environ", "rb").read()
except (FileNotFoundError, PermissionError, ProcessLookupError, OSError):
    # Identity could not be read for a PID that was (at least momentarily)
    # alive. This is NOT the same as absence: absence is decided by the
    # caller via a liveness check before this function ever runs. Any read
    # failure here fails closed as unresolved (exit 2), never as a silent
    # mismatch (exit 1).
    sys.exit(2)
fields = set(environ.split(b"\0"))
if executable == pg_executable:
    sys.exit(0 if pgdata_marker in fields else 1)
if os.path.dirname(executable) == bin_dir and bus_dir_marker in fields:
    sys.exit(0)
sys.exit(1)
PY
}

# Tri-state ownership for a PID that is candidate attempt-owned:
#   absent      - PID is not running (separately clean, never a survivor)
#   owned       - identity re-read confirms this attempt's executable+marker
#   mismatched  - identity re-read positively contradicts ownership
#   unresolved  - PID is running but identity could not be read; fail closed
attempt_pid_identity_state() {
  local pid="$1"
  local bin_dir="$2"
  local pg_bin="$3"
  local stack_dir="$4"
  if ! owned_pid_running "$pid"; then
    printf 'absent\n'
    return
  fi
  attempt_pid_still_owned "$pid" "$bin_dir" "$pg_bin" "$stack_dir"
  case $? in
    0) printf 'owned\n' ;;
    2) printf 'unresolved\n' ;;
    *) printf 'mismatched\n' ;;
  esac
}

should_signal_attempt_pid() {
  local pid="$1"
  [[ "$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" == "owned" ]]
}

blocked_listen_ports() {
  local host="$1"
  shift
  python3 - "$host" "$@" <<'PY'
import socket
import sys

host = sys.argv[1]
for port in (int(p) for p in sys.argv[2:]):
    sock = socket.socket()
    # SO_REUSEADDR must be set before bind: without it, a port left in
    # TIME_WAIT by a prior server-side close is indistinguishable from a
    # live LISTEN socket for roughly 60 seconds, and this probe would
    # misreport the port as blocked.
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind((host, port))
    except OSError:
        print(port)
    finally:
        sock.close()
PY
}

attempt_listening_ports() {
  blocked_listen_ports "$BUS_HOST" 8081 8090
}

stop_attempt_owned_processes() {
  local baseline="$1"
  local -A target_pids=()
  local name pid late_pid late_exe late_marker blocked_port
  : >"$RESULT_ABS/late-owned.tsv"
  if [[ -f "$baseline" ]]; then
    while IFS=$'\t' read -r name pid; do
      [[ "$name" == "subscription" ]] && continue
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      target_pids["$pid"]=1
    done <"$baseline"
  fi
  while IFS=$'\t' read -r late_pid late_exe late_marker; do
    [[ "$late_pid" =~ ^[0-9]+$ ]] || continue
    [[ -n "${target_pids[$late_pid]:-}" ]] || printf 'late_owned\t%s\t%s\t%s\n' "$late_pid" "$late_exe" "$late_marker" >>"$RESULT_ABS/late-owned.tsv"
    target_pids["$late_pid"]=1
  done < <(owned_attempt_pids "$BIN_DIR" "$PG_BIN" "$STACK_DIR")

  for pid in "${!target_pids[@]}"; do
    case "$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" in
      owned) kill -TERM "$pid" 2>/dev/null || true ;;
      mismatched) printf 'identity_rejected\tterm\t%s\n' "$pid" >>"$RESULT_ABS/late-owned.tsv" ;;
      unresolved) printf 'identity_unresolved\tterm\t%s\n' "$pid" >>"$RESULT_ABS/late-owned.tsv" ;;
      absent) ;;
    esac
  done
  for pid in "${!target_pids[@]}"; do
    owned_pid_running "$pid" || continue
    timeout 10s tail --pid="$pid" -f /dev/null 2>/dev/null || true
  done

  while IFS=$'\t' read -r late_pid late_exe late_marker; do
    [[ "$late_pid" =~ ^[0-9]+$ ]] || continue
    [[ -n "${target_pids[$late_pid]:-}" ]] || printf 'late_owned\t%s\t%s\t%s\n' "$late_pid" "$late_exe" "$late_marker" >>"$RESULT_ABS/late-owned.tsv"
    target_pids["$late_pid"]=1
  done < <(owned_attempt_pids "$BIN_DIR" "$PG_BIN" "$STACK_DIR")

  for pid in "${!target_pids[@]}"; do
    case "$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" in
      owned)
        kill -KILL "$pid" 2>/dev/null || true
        timeout 5s tail --pid="$pid" -f /dev/null 2>/dev/null || true
        ;;
      mismatched) printf 'identity_rejected\tkill\t%s\n' "$pid" >>"$RESULT_ABS/late-owned.tsv" ;;
      unresolved) printf 'identity_unresolved\tkill\t%s\n' "$pid" >>"$RESULT_ABS/late-owned.tsv" ;;
      absent) ;;
    esac
  done

  local remaining=0
  for pid in "${!target_pids[@]}"; do
    case "$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" in
      owned) remaining=$((remaining + 1)) ;;
      unresolved)
        remaining=$((remaining + 1))
        printf 'identity_unresolved\tfinal\t%s\n' "$pid" >>"$RESULT_ABS/late-owned.tsv"
        ;;
    esac
  done
  while IFS=$'\t' read -r late_pid late_exe late_marker; do
    [[ "$late_pid" =~ ^[0-9]+$ ]] || continue
    remaining=$((remaining + 1))
  done < <(owned_attempt_pids "$BIN_DIR" "$PG_BIN" "$STACK_DIR")
  while IFS= read -r blocked_port; do
    [[ -n "$blocked_port" ]] || continue
    printf 'blocked_port\t%s\n' "$blocked_port" >>"$RESULT_ABS/late-owned.tsv"
    remaining=$((remaining + 1))
  done < <(attempt_listening_ports)
  ((remaining == 0))
}

regression_test_owned_attempt_pids() {
  local test_root="$RUNTIME_DIR/selftest-owned-pids"
  local test_bin="$test_root/bin"
  local test_stack="$test_root/stack"
  local other_stack="$test_root/other-stack"
  rm -rf "$test_root"
  mkdir -p "$test_bin" "$test_stack/.bus" "$other_stack/.bus"
  # The real Events and API children run the exact same shared "bus" binary
  # as every other attempt-owned process (profiles bus/events/postgres and
  # bus/api/local both use `command: [bus]`); a real ELF copy at this path
  # is required so /proc/<pid>/exe resolves directly to it, not to a
  # shebang interpreter or exec() target.
  cp "$(command -v sleep)" "$test_bin/bus"

  env BUS_SERVICES_BUS_DIR="$test_stack/.bus" "$test_bin/bus" 300 &
  local matching_pid=$!
  # A second, independently tracked child of the same attempt-owned
  # executable+marker shape as the real Events/API children: the ownership
  # predicate keys only on executable path and the BUS_SERVICES_BUS_DIR
  # marker, never on argv, so this proves discovery/classification works
  # when multiple owned children (as Events and API are) exist together.
  env BUS_SERVICES_BUS_DIR="$test_stack/.bus" "$test_bin/bus" 300 &
  local events_api_pid=$!
  sleep 300 &
  local unrelated_pid=$!
  env BUS_SERVICES_BUS_DIR="$other_stack/.bus" "$test_bin/bus" 300 &
  local mismatched_pid=$!
  sleep 0.2

  local -A found_set=()
  local found_pid found_exe found_marker
  while IFS=$'\t' read -r found_pid found_exe found_marker; do
    [[ "$found_pid" =~ ^[0-9]+$ ]] || continue
    found_set["$found_pid"]=1
  done < <(owned_attempt_pids "$test_bin" "$test_root/no-postgres" "$test_stack")

  local signal_rc_matching=0 signal_rc_events_api=0 signal_rc_unrelated=0 signal_rc_mismatched=0
  attempt_pid_still_owned "$matching_pid" "$test_bin" "$test_root/no-postgres" "$test_stack" || signal_rc_matching=$?
  attempt_pid_still_owned "$events_api_pid" "$test_bin" "$test_root/no-postgres" "$test_stack" || signal_rc_events_api=$?
  attempt_pid_still_owned "$unrelated_pid" "$test_bin" "$test_root/no-postgres" "$test_stack" || signal_rc_unrelated=$?
  attempt_pid_still_owned "$mismatched_pid" "$test_bin" "$test_root/no-postgres" "$test_stack" || signal_rc_mismatched=$?

  local state_matching state_events_api state_unrelated state_mismatched
  state_matching="$(attempt_pid_identity_state "$matching_pid" "$test_bin" "$test_root/no-postgres" "$test_stack")"
  state_events_api="$(attempt_pid_identity_state "$events_api_pid" "$test_bin" "$test_root/no-postgres" "$test_stack")"
  state_unrelated="$(attempt_pid_identity_state "$unrelated_pid" "$test_bin" "$test_root/no-postgres" "$test_stack")"
  state_mismatched="$(attempt_pid_identity_state "$mismatched_pid" "$test_bin" "$test_root/no-postgres" "$test_stack")"

  # A PID that has fully exited and been reaped before this call: attempt_pid_still_owned
  # must fail closed as unresolved (2), not silently as a mismatch (1), when identity
  # cannot be read for a PID that was momentarily live. Absence itself is decided
  # separately by attempt_pid_identity_state's own liveness check, never by this
  # function's read-failure path.
  ( : ) &
  local reaped_pid=$!
  wait "$reaped_pid" 2>/dev/null || true
  local unresolved_rc=0
  attempt_pid_still_owned "$reaped_pid" "$test_bin" "$test_root/no-postgres" "$test_stack" || unresolved_rc=$?

  kill -KILL "$matching_pid" "$events_api_pid" "$unrelated_pid" "$mismatched_pid" 2>/dev/null || true
  wait "$matching_pid" "$events_api_pid" "$unrelated_pid" "$mismatched_pid" 2>/dev/null || true
  rm -rf "$test_root"

  [[ -n "${found_set[$matching_pid]:-}" ]] || die "self-test: late attempt-owned child was not discovered"
  [[ -n "${found_set[$events_api_pid]:-}" ]] || die "self-test: Events/API-shaped attempt-owned child was not discovered"
  [[ -z "${found_set[$unrelated_pid]:-}" ]] || die "self-test: unrelated same-user process was incorrectly treated as attempt-owned"
  [[ -z "${found_set[$mismatched_pid]:-}" ]] || die "self-test: identity-mismatched process was incorrectly treated as attempt-owned"
  ((signal_rc_matching == 0)) || die "self-test: late matching child failed the pre-signal identity recheck"
  ((signal_rc_events_api == 0)) || die "self-test: Events/API-shaped child failed the pre-signal identity recheck"
  ((signal_rc_unrelated != 0)) || die "self-test: unrelated same-user process passed the pre-signal identity recheck"
  ((signal_rc_mismatched != 0)) || die "self-test: identity-mismatched process passed the pre-signal identity recheck"
  ((unresolved_rc == 2)) || die "self-test: unreadable identity for a momentarily-live PID was not treated as fail-closed unresolved"

  [[ "$state_matching" == "owned" ]] || die "self-test: matching child was not classified as owned"
  [[ "$state_events_api" == "owned" ]] || die "self-test: Events/API-shaped child was not classified as owned"
  [[ "$state_unrelated" == "mismatched" ]] || die "self-test: unrelated same-user process was not classified as mismatched"
  [[ "$state_mismatched" == "mismatched" ]] || die "self-test: identity-mismatched process was not classified as mismatched"
  # The mismatched process must never be counted as an attempt survivor: the
  # production remaining-count predicate treats only owned/unresolved as a
  # survivor, so a "mismatched" classification must not be either of those.
  [[ "$state_mismatched" != "owned" && "$state_mismatched" != "unresolved" ]] ||
    die "self-test: identity-mismatched process would be counted as an attempt survivor"
}

regression_test_assert_baseline_pids_owned() {
  local test_root="$RUNTIME_DIR/selftest-baseline-owned"
  local test_bin="$test_root/bin"
  local test_stack="$test_root/stack"
  local other_stack="$test_root/other-stack"
  rm -rf "$test_root"
  mkdir -p "$test_bin" "$test_stack/.bus" "$other_stack/.bus"
  cp "$(command -v sleep)" "$test_bin/bus"

  env BUS_SERVICES_BUS_DIR="$test_stack/.bus" "$test_bin/bus" 300 &
  local owned_child_pid=$!
  env BUS_SERVICES_BUS_DIR="$other_stack/.bus" "$test_bin/bus" 300 &
  local mismatched_child_pid=$!
  sleep 300 &
  local controller_pid=$!
  sleep 300 &
  local other_pid=$!
  sleep 0.2

  local good_pidfile="$test_root/good.tsv"
  local mismatched_pidfile="$test_root/mismatched-child.tsv"
  printf 'serve\t%s\npostgres\t%s\n' "$controller_pid" "$owned_child_pid" >"$good_pidfile"
  printf 'serve\t%s\npostgres\t%s\n' "$controller_pid" "$mismatched_child_pid" >"$mismatched_pidfile"

  # owned_controller_pids is stubbed to a canned list for this self-test:
  # exercising the real /proc cmdline scan would require faking
  # bus-integration-services' exact serve/--state-dir argv shape, but the
  # role-aware branch under test only depends on what the function returns,
  # not on how it derives that list. The original definition is restored
  # afterward so every other call site keeps the real implementation.
  local original_owned_controller_pids
  original_owned_controller_pids="$(declare -f owned_controller_pids)"
  local rc_ok rc_wrong_controller rc_multi_controller rc_mismatched_child

  owned_controller_pids() { printf '%s\n' "$controller_pid"; }
  (
    BIN_DIR="$test_bin" PG_BIN="$test_root/no-postgres" STACK_DIR="$test_stack" RESULT_ABS=""
    assert_baseline_pids_owned "$good_pidfile"
  )
  rc_ok=$?

  owned_controller_pids() { printf '%s\n' "$other_pid"; }
  (
    BIN_DIR="$test_bin" PG_BIN="$test_root/no-postgres" STACK_DIR="$test_stack" RESULT_ABS=""
    assert_baseline_pids_owned "$good_pidfile"
  )
  rc_wrong_controller=$?

  owned_controller_pids() { printf '%s\n%s\n' "$controller_pid" "$other_pid"; }
  (
    BIN_DIR="$test_bin" PG_BIN="$test_root/no-postgres" STACK_DIR="$test_stack" RESULT_ABS=""
    assert_baseline_pids_owned "$good_pidfile"
  )
  rc_multi_controller=$?

  owned_controller_pids() { printf '%s\n' "$controller_pid"; }
  (
    BIN_DIR="$test_bin" PG_BIN="$test_root/no-postgres" STACK_DIR="$test_stack" RESULT_ABS=""
    assert_baseline_pids_owned "$mismatched_pidfile"
  )
  rc_mismatched_child=$?

  eval "$original_owned_controller_pids"

  kill -KILL "$owned_child_pid" "$mismatched_child_pid" "$controller_pid" "$other_pid" 2>/dev/null || true
  wait "$owned_child_pid" "$mismatched_child_pid" "$controller_pid" "$other_pid" 2>/dev/null || true
  rm -rf "$test_root"

  ((rc_ok == 0)) || die "self-test: baseline assertion rejected a sole controller with an owned child"
  ((rc_wrong_controller != 0)) || die "self-test: baseline assertion accepted a serve pid that is not the sole controller owner"
  ((rc_multi_controller != 0)) || die "self-test: baseline assertion accepted serve pid alongside multiple controller owners"
  ((rc_mismatched_child != 0)) || die "self-test: baseline assertion accepted an identity-mismatched child row"
}

regression_test_attempt_listening_ports() {
  local host="127.0.0.1"
  local time_wait_port live_port port_file listener_pid deadline

  time_wait_port="$(python3 - "$host" <<'PY'
import socket
import sys

host = sys.argv[1]
server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((host, 0))
port = server.getsockname()[1]
server.listen(1)
client = socket.socket()
client.connect((host, port))
conn, _ = server.accept()
# Server-side active close: this is what drives the server's local port into
# TIME_WAIT, the exact state a plain bind() misclassifies as still listening.
conn.close()
client.close()
server.close()
print(port)
PY
  )"
  [[ "$time_wait_port" =~ ^[0-9]+$ ]] || die "self-test: failed to produce a TIME_WAIT port for the listener probe"

  local -a time_wait_blocked=()
  mapfile -t time_wait_blocked < <(blocked_listen_ports "$host" "$time_wait_port")
  ((${#time_wait_blocked[@]} == 0)) ||
    die "self-test: TIME_WAIT port $time_wait_port was incorrectly reported as blocked by a live listener"

  port_file="$RUNTIME_DIR/selftest-listener.port"
  rm -f "$port_file"
  python3 - "$host" >"$port_file" <<'PY' &
import socket
import sys
import time

host = sys.argv[1]
server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((host, 0))
port = server.getsockname()[1]
server.listen(1)
print(port, flush=True)
time.sleep(10)
PY
  listener_pid=$!

  live_port=""
  deadline=$((SECONDS + 5))
  while ((SECONDS < deadline)); do
    if [[ -s "$port_file" ]]; then
      live_port="$(<"$port_file")"
      break
    fi
    sleep 0.05
  done
  if [[ ! "$live_port" =~ ^[0-9]+$ ]]; then
    kill -KILL "$listener_pid" 2>/dev/null || true
    wait "$listener_pid" 2>/dev/null || true
    rm -f "$port_file"
    die "self-test: failed to start a live listener for the listener probe"
  fi

  local -a live_blocked=()
  mapfile -t live_blocked < <(blocked_listen_ports "$host" "$live_port")
  kill -KILL "$listener_pid" 2>/dev/null || true
  wait "$listener_pid" 2>/dev/null || true
  rm -f "$port_file"

  ((${#live_blocked[@]} == 1 && live_blocked[0] == live_port)) ||
    die "self-test: live listener on port $live_port was not reported as blocked"
}

cleanup() {
  local original_rc="${1:-1}"
  local down_rc=0
  local survivors=0
  local audit_rc=0
  local repos_rc=0
  trap - EXIT INT TERM
  set +e
  if [[ -n "$SUBSCRIPTION_PID" ]] && owned_pid_running "$SUBSCRIPTION_PID"; then
    kill -TERM "$SUBSCRIPTION_PID" 2>/dev/null
    timeout 5s tail --pid="$SUBSCRIPTION_PID" -f /dev/null 2>/dev/null
  fi
  if ((STACK_STARTED == 1)); then
    record_command cleanup-down "$BIN_DIR/bus-services" down --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR"
    timeout 40s "$BIN_DIR/bus-services" down --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR" >"$RESULT_ABS/cleanup-down.stdout" 2>"$RESULT_ABS/cleanup-down.stderr"
    down_rc=$?
    printf 'down_exit\t%s\n' "$down_rc" >"$RESULT_ABS/cleanup.tsv"
    if ((down_rc != 0)) && grep -q 'open pinned bus-integration-services pid' "$RESULT_ABS/cleanup-down.stderr" 2>/dev/null; then
      printf 'down_stale_pinned_owner\tobserved\n' >>"$RESULT_ABS/cleanup.tsv"
      if stop_attempt_owned_processes "$RESULT_ABS/pids.initial.tsv"; then
        printf 'down_owned_fallback\tzero_survivor\n' >>"$RESULT_ABS/cleanup.tsv"
        down_rc=0
      else
        printf 'down_owned_fallback\tsurvivor_remained\n' >>"$RESULT_ABS/cleanup.tsv"
      fi
      if [[ -s "$RESULT_ABS/late-owned.tsv" ]]; then
        cat "$RESULT_ABS/late-owned.tsv" >>"$RESULT_ABS/cleanup.tsv"
      fi
    fi
  else
    down_rc=0
    printf 'down_exit\tnot_started\n' >"$RESULT_ABS/cleanup.tsv"
  fi
  if [[ -f "$RESULT_ABS/pids.initial.tsv" ]]; then
    while IFS=$'\t' read -r name pid; do
      if [[ "$name" == "subscription" ]]; then
        if owned_pid_running "$pid"; then
          printf 'survivor\t%s\t%s\n' "$name" "$pid" >>"$RESULT_ABS/cleanup.tsv"
          survivors=$((survivors + 1))
        fi
        continue
      fi
      case "$(attempt_pid_identity_state "$pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" in
        owned|unresolved)
          printf 'survivor\t%s\t%s\n' "$name" "$pid" >>"$RESULT_ABS/cleanup.tsv"
          survivors=$((survivors + 1))
          ;;
      esac
    done <"$RESULT_ABS/pids.initial.tsv"
  fi
  if [[ -f "$RESULT_ABS/late-owned.tsv" ]]; then
    while IFS=$'\t' read -r kind late_pid late_rest1 late_rest2; do
      case "$kind" in
        late_owned)
          case "$(attempt_pid_identity_state "$late_pid" "$BIN_DIR" "$PG_BIN" "$STACK_DIR")" in
            owned|unresolved)
              printf 'survivor\tlate\t%s\n' "$late_pid" >>"$RESULT_ABS/cleanup.tsv"
              survivors=$((survivors + 1))
              ;;
          esac
          ;;
        blocked_port)
          printf 'survivor\tport\t%s\n' "$late_pid" >>"$RESULT_ABS/cleanup.tsv"
          survivors=$((survivors + 1))
          ;;
      esac
    done <"$RESULT_ABS/late-owned.tsv"
  fi
  rm -f "$STACK_DIR/.env"
  printf 'survivor_count\t%s\n' "$survivors" >>"$RESULT_ABS/cleanup.tsv"
  if [[ "$FINAL_STATUS" == "passed" ]]; then
    verify_retained_repositories 1
  else
    verify_retained_repositories 0
  fi
  repos_rc=$?
  audit_retained_artifacts
  audit_rc=$?
  chmod -R u+w "$RUNTIME_DIR/cache" 2>/dev/null || true
  rm -rf "$STACK_DIR/.bus/tokens" \
    "$STACK_DIR/.bus/services/workers/runtime" "$STACK_DIR/postgres" \
    "$PG_SOCKET_DIR" "$RUNTIME_DIR/cache" "$RUNTIME_DIR/go-tmp" "$SOURCE_DIR"
  if ((original_rc != 0 || down_rc != 0 || survivors != 0 || repos_rc != 0 || audit_rc != 0)) || [[ "$FINAL_STATUS" != "passed" ]]; then
    FINAL_STATUS="failed"
    ((original_rc != 0)) || original_rc=1
  fi
  printf 'finished_at\t%s\nstatus\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$FINAL_STATUS" >>"$RESULT_ABS/run.tsv"
  set -e
  if ((down_rc != 0 || survivors != 0 || repos_rc != 0 || audit_rc != 0)); then
    printf 'ERROR: cleanup or retained-artifact audit failed\n' >&2
  fi
  exit "$original_rc"
}
trap 'cleanup "$?"' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

materialize_module() {
  local module="$1"
  local ref repo
  if [[ -n "${OVERRIDE_REFS[$module]:-}" ]]; then
    ref="${OVERRIDE_REFS[$module]}"
  else
    ref="$(module_pin "$module")"
  fi
  repo="$(module_repo_for_ref "$module" "$ref")" || die "source repository lacks $module@$ref"
  mkdir -p "$SOURCE_DIR/$module"
  git -C "$repo" archive "$ref" | tar -x -C "$SOURCE_DIR/$module"
  printf '%s\t%s\t%s\n' "$module" "$ref" "$repo" >>"$RESULT_ABS/refs.tsv"
}

declare -A MATERIALIZED=()
MODULE_QUEUE=(
  bus bus-services bus-integration-services bus-api bus-api-provider-identities
  bus-integration bus-integration-thread bus-integration-worker
  bus-integration-repos bus-thread bus-worker bus-repos bus-events
)
queue_index=0
while ((queue_index < ${#MODULE_QUEUE[@]})); do
  module="${MODULE_QUEUE[$queue_index]}"
  queue_index=$((queue_index + 1))
  [[ -z "${MATERIALIZED[$module]:-}" ]] || continue
  materialize_module "$module"
  MATERIALIZED[$module]=1
  if [[ -f "$SOURCE_DIR/$module/go.mod" ]]; then
    while IFS= read -r dependency; do
      dependency="${dependency%%/*}"
      [[ -n "$dependency" ]] || continue
      if git -C "$ROOT_DIR" ls-tree "$BUSDK_REF" -- "$dependency" | grep -q '^160000 '; then
        MODULE_QUEUE+=("$dependency")
      fi
    done < <(sed -nE 's|.*=>[[:space:]]+\.\./([^[:space:]]+).*|\1|p' "$SOURCE_DIR/$module/go.mod")
  fi
done

git -C "$ROOT_DIR" archive "$BUSDK_REF" profiles scripts .bus/worker agents/worker | tar -x -C "$STACK_DIR"

export GOCACHE="$RUNTIME_DIR/cache/go-build"
export GOMODCACHE="$RUNTIME_DIR/cache/go-mod"
export GOTMPDIR="$RUNTIME_DIR/go-tmp"
export GOMAXPROCS=2

regression_test_owned_attempt_pids
regression_test_assert_baseline_pids_owned
regression_test_attempt_listening_ports

build_binary() {
  local module="$1"
  local package="$2"
  local output="$3"
  local label="build-${output}"
  record_command "$label" go build -mod=mod -p=2 -trimpath -buildvcs=false -o "$BIN_DIR/$output" "$package"
  start="$(date +%s%N)"
  if ! (cd "$SOURCE_DIR/$module" && timeout 10m go build -mod=mod -p=2 -trimpath -buildvcs=false -o "$BIN_DIR/$output" "$package") >"$RESULT_ABS/operations/$label.stdout" 2>"$RESULT_ABS/operations/$label.stderr"; then
    printf '%s\t1\n' "$label" >>"$RESULT_ABS/exits.tsv"
    die "failed to build $output"
  fi
  end="$(date +%s%N)"
  printf '%s\t0\n' "$label" >>"$RESULT_ABS/exits.tsv"
  printf '%s\t%s\t%s\n' "$label" "$start" "$end" >>"$RESULT_ABS/timings.tsv"
}

build_binary bus ./cmd/bus bus
build_binary bus-services ./cmd/bus-services bus-services
build_binary bus-integration-services ./cmd/bus-integration-services bus-integration-services
build_binary bus-api ./cmd/bus-api bus-api
build_binary bus-api-provider-identities ./cmd/bus-api-provider-identities bus-api-provider-identities
build_binary bus-integration ./cmd/bus-integration bus-integration
build_binary bus-integration-thread ./cmd/bus-integration-thread bus-integration-thread
build_binary bus-integration-worker ./cmd/bus-integration-workers bus-integration-workers
build_binary bus-integration-repos ./cmd/bus-integration-repos bus-integration-repos
build_binary bus-thread ./cmd/bus-thread bus-thread
build_binary bus-worker ./cmd/bus-worker bus-worker
build_binary bus-worker ./cmd/bus-workers bus-workers
build_binary bus-repos ./cmd/bus-repos bus-repos
build_binary bus-events ./cmd/bus-events bus-events

SECRET="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
PG_SOCKET_DIR="/tmp/busdk-t131-pg-$$"
mkdir -p "$STACK_DIR/.bus" "$PG_SOCKET_DIR"
cat >"$STACK_DIR/.env" <<EOF
BUS_HOST=$BUS_HOST
BUS_API_JWT_SECRET=$SECRET
BUS_AUTH_HS256_SECRET=$SECRET
BUS_SERVICES_BUS_DIR=$STACK_DIR/.bus
BUS_SERVICES_STACK_DIR=$STACK_DIR
BUS_SERVICES_LOCAL_EVENTS_TOKEN_TTL_SECONDS=$TTL_SECONDS
BUS_SERVICES_LOCAL_EVENTS_TOKEN_REFRESH_BEFORE_SECONDS=$RENEW_SECONDS
BUS_POSTGRES_PORT=5432
BUS_POSTGRES_PGDATA=$STACK_DIR/postgres/data
BUS_POSTGRES_SOCKET_DIR=$PG_SOCKET_DIR
BUS_EVENTS_PORT=8081
BUS_EVENTS_POSTGRES_DSN=postgres://bus_service@$BUS_HOST:5432/postgres?sslmode=disable
BUS_EVENTS_URL=$EVENTS_URL
BUS_IDENTITIES_API_HOST=$BUS_HOST
BUS_IDENTITIES_API_PORT=8091
BUS_API_IDENTITIES_API_URL=http://$BUS_HOST:8091
BUS_API_PORT=8090
BUS_API_URL=$API_URL
BUS_WORKERS_API_URL=$API_URL
BUS_WORKERS_DIRECT_REPO_ROOT=$ROOT_DIR
BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO=$ROOT_DIR
BUS_WORKERS_DIRECT_WORKER_ROOT=$STACK_DIR/.bus/services/workers/runtime
EOF
unset SECRET

cat >"$STACK_DIR/services.yml" <<EOF
version: "0"
env_files:
  - .env
profile_dirs:
  - profiles
default_services:
  - postgres
  - identities
  - events
  - repos
  - workers
  - threads
  - api
services:
  postgres:
    profile: postgres/native
    params:
      host: $BUS_HOST
  identities:
    profile: bus/identities/local
    params:
      host: $BUS_HOST
      listen: $BUS_HOST
      port: 8091
  events:
    profile: bus/events/postgres
    params:
      host: $BUS_HOST
      capability_token: local
      postgres_host: $BUS_HOST
      postgres_port: 5432
    runtime:
      env:
        - name: BUS_HOST
          value: $BUS_HOST
        - name: BUS_SERVICES_BUS_DIR
          value: $STACK_DIR/.bus
    depends_on:
      - identities
      - postgres
  repos:
    profile: bus/repos/local
    params:
      host: $BUS_HOST
      events_url: $EVENTS_URL
    runtime:
      options:
        init:
          command:
            - /bin/sh
          args:
            - $STACK_DIR/scripts/bus-repos-local-init.sh
          creates: "{env:BUS_REPOS_CONFIG}"
    depends_on:
      - events
  workers:
    profile: bus/workers/appserver
    params:
      host: $BUS_HOST
      events_url: $EVENTS_URL
    depends_on:
      - events
      - repos
  threads:
    profile: bus/threads/local
    params:
      host: $BUS_HOST
      events_url: $EVENTS_URL
    depends_on:
      - events
  api:
    profile: bus/api/local
    params:
      host: $BUS_HOST
      capability_token: local
      providers: workers,thread,repos
    runtime:
      env:
        - name: BUS_HOST
          value: $BUS_HOST
        - name: BUS_SERVICES_BUS_DIR
          value: $STACK_DIR/.bus
    depends_on:
      - identities
      - events
      - repos
      - workers
      - threads
EOF

export PATH="$BIN_DIR:$PG_BIN:$PATH"
export BUS_INTEGRATION_SERVICES_BIN="$BIN_DIR/bus-integration-services"
export BUS_SERVICES_TOOL_PATH="$BIN_DIR:$PG_BIN:$PATH"
export GIT_CEILING_DIRECTORIES="$RESULT_ABS"

if git -C "$STACK_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  die "generated stack fixture unexpectedly resolves inside a Git worktree"
fi

run_capture fixture-validate "$BIN_DIR/bus-services" stack validate --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR"
STACK_STARTED=1
run_capture_with_timeout services-up 90s "$BIN_DIR/bus-services" up --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR"
[[ -s "$TOKEN_FILE" ]] || die "Services did not create the local Events token file"

capture_pids "$RESULT_ABS/pids.initial.tsv"
assert_baseline_pids_owned "$RESULT_ABS/pids.initial.tsv"
cp "$RESULT_ABS/pids.initial.tsv" "$RESULT_ABS/pids.startup.tsv"

run_capture thread-create "$BIN_DIR/bus-thread" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" --format json create --title "Thread 131 continuity" --body "short TTL process proof" --author "thread131-harness" --status open
THREAD_ID="$(jq -r '.thread.thread_id // empty' "$RESULT_ABS/operations/thread-create.stdout")"
[[ "$THREAD_ID" =~ ^[0-9]+$ ]] || die "Thread create did not return a thread id"

assert_worker_status() {
  local label="$1"
  local expected_worker_id="$2"
  jq -e --arg worker_id "$expected_worker_id" '
    .id == $worker_id and
    .environment_id == "local" and
    (.status | type == "string" and length > 0)
  ' "$RESULT_ABS/operations/$label.stdout" >/dev/null || die "$label returned unexpected Worker identity"
}

assert_worker_message() {
  local label="$1"
  local expected_worker_id="$2"
  local expected_message_id="$3"
  local expected_text="$4"
  jq -e --arg worker_id "$expected_worker_id" --arg message_id "$expected_message_id" --arg text "$expected_text" '
    .worker_id == $worker_id and
    .environment_id == "local" and
    .message_id == $message_id and
    .text == $text and
    .status == "accepted" and
    .direction == "operator_to_worker" and
    .role == "operator"
  ' "$RESULT_ABS/operations/$label.stdout" >/dev/null || die "$label returned unexpected Worker message semantics"
}

assert_thread_show() {
  local label="$1"
  local expected_thread_id="$2"
  local expected_marker="$3"
  jq -e --argjson thread_id "$expected_thread_id" --arg marker "$expected_marker" '
    .thread.thread_id == $thread_id and
    .thread.root_thread_id == $thread_id and
    any(.thread.messages[]?;
      .thread_id == $thread_id and
      .text == $marker and
      .author.id == "thread131-harness"
    )
  ' "$RESULT_ABS/operations/$label.stdout" >/dev/null || die "$label returned unexpected Thread semantics"
}

WORKER_ID="thread131-continuity"
run_capture worker-create "$BIN_DIR/bus-workers" --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json create --id "$WORKER_ID" --label "Thread 131 continuity" --type human --profile human --environment local
assert_worker_status worker-create "$WORKER_ID"
run_capture worker-initial-status "$BIN_DIR/bus-workers" --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json status "$WORKER_ID" --environment local
assert_worker_status worker-initial-status "$WORKER_ID"
INITIAL_REPO_PATH="$STACK_DIR/.bus/repos/storage/product.git"
[[ -f "$INITIAL_REPO_PATH/HEAD" ]] && [[ "$(git --git-dir="$INITIAL_REPO_PATH" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]] || die "Repos service did not materialize its initial bare product repository"
printf 'initial\t%s\tproduct\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INITIAL_REPO_PATH" >"$RESULT_ABS/repos-materialization.tsv"

record_command subscription-start "$BIN_DIR/bus-events" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" --timeout 45s listen --name bus.thread.message
"$BIN_DIR/bus-events" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" --timeout 45s listen --name bus.thread.message >"$RESULT_ABS/subscription.ndjson" 2>"$RESULT_ABS/subscription.stderr" &
SUBSCRIPTION_PID=$!
sleep 0.2
owned_pid_running "$SUBSCRIPTION_PID" || die "subscription process did not remain open"

token_metadata() {
  local label="$1"
  local size mtime
  TOKEN_HASH="$(sha256sum "$TOKEN_FILE" | awk '{print $1}')"
  read -r TOKEN_INODE size mtime < <(stat -c '%i %s %Y' "$TOKEN_FILE")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TOKEN_HASH" "$TOKEN_INODE" "$size" "$mtime" >>"$RESULT_ABS/rotations.tsv"
}

wait_for_rotation() {
  local prior_hash="$1"
  local deadline=$((SECONDS + TTL_SECONDS + RENEW_SECONDS + 10))
  local current_hash
  WAITED_HASH=""
  while ((SECONDS < deadline)); do
    if [[ -s "$TOKEN_FILE" ]]; then
      current_hash="$(sha256sum "$TOKEN_FILE" | awk '{print $1}')"
      [[ "$current_hash" != "$prior_hash" ]] && { WAITED_HASH="$current_hash"; return; }
    fi
    sleep 0.1
  done
  return 1
}

wait_for_subscription_marker() {
  local marker="$1"
  local expected_thread_id="$2"
  local deadline=$((SECONDS + 10))
  while ((SECONDS < deadline)); do
    if jq -e --arg marker "$marker" --argjson thread_id "$expected_thread_id" '
      select(
        .name == "bus.thread.message" and
        .payload.thread_id == $thread_id and
        .payload.text == $marker and
        .payload.author.id == "thread131-harness"
      )
    ' "$RESULT_ABS/subscription.ndjson" >/dev/null 2>&1; then
      return 0
    fi
    owned_pid_running "$SUBSCRIPTION_PID" || return 1
    sleep 0.1
  done
  return 1
}

wait_for_repo_materialization() {
  local label="$1"
  local repo_id="$2"
  local repo_path="$STACK_DIR/.bus/repos/storage/$repo_id.git"
  local deadline=$((SECONDS + 15))
  while ((SECONDS < deadline)); do
    if [[ -f "$repo_path/HEAD" ]] && [[ "$(git --git-dir="$repo_path" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
      printf '%s\t%s\t%s\t%s\n' "$label" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$repo_id" "$repo_path" >>"$RESULT_ABS/repos-materialization.tsv"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

token_metadata initial
INITIAL_HASH="$TOKEN_HASH"
INITIAL_INODE="$TOKEN_INODE"
READINESS_MARKER="thread131-readiness-$THREAD_ID-$(date +%s%N)"
run_capture subscription-readiness-send "$BIN_DIR/bus-thread" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" send "$THREAD_ID" --author thread131-harness "$READINESS_MARKER"
wait_for_subscription_marker "$READINESS_MARKER" "$THREAD_ID" || die "already-open subscription missed its readiness marker"
token_metadata subscription-ready
READY_HASH="$TOKEN_HASH"
READY_INODE="$TOKEN_INODE"
[[ "$READY_HASH" == "$INITIAL_HASH" ]] || die "credential changed before subscription readiness was proven"
printf 'thread_id\t%s\nmarker\t%s\nhash_before\t%s\nhash_after\t%s\nstatus\tobserved\n' \
  "$THREAD_ID" "$READINESS_MARKER" "$INITIAL_HASH" "$READY_HASH" >"$RESULT_ABS/subscription.tsv"
capture_pids "$RESULT_ABS/pids.initial.tsv"

CONTROLLER_PID="$(awk -F '\t' '$1 == "serve" {print $2}' "$RESULT_ABS/pids.initial.tsv")"
mapfile -t STARTUP_OWNERS < <(owned_controller_pids)
if ((${#STARTUP_OWNERS[@]} != 1)) || [[ "${STARTUP_OWNERS[0]}" != "$CONTROLLER_PID" ]] || ! owned_pid_active "$CONTROLLER_PID"; then
  die "ordinary up did not leave exactly one owned, active renewal controller"
fi
printf 'controller_before\t%s\nowner_count_before\t%s\n' "$CONTROLLER_PID" "${#STARTUP_OWNERS[@]}" >"$RESULT_ABS/reattach.tsv"

record_command controller-sigkill kill -KILL "$CONTROLLER_PID"
if ! kill -KILL "$CONTROLLER_PID"; then
  die "failed to SIGKILL the owned renewal controller"
fi
wait_for_controller_exit "$CONTROLLER_PID" || die "owned renewal controller did not exit after SIGKILL"
printf 'controller_exit\tobserved\n' >>"$RESULT_ABS/reattach.tsv"

run_capture owner-health-after-kill "$BIN_DIR/bus-services" list --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR" --format json
DEGRADED_OWNER_STATUS="$(jq -r '.renewal_owner.status // empty' "$RESULT_ABS/operations/owner-health-after-kill.stdout")"
DEGRADED_OWNER_REASON="$(jq -r '.renewal_owner.reason // empty' "$RESULT_ABS/operations/owner-health-after-kill.stdout")"
printf 'degraded_status\t%s\ndegraded_reason\t%s\n' "$DEGRADED_OWNER_STATUS" "$DEGRADED_OWNER_REASON" >>"$RESULT_ABS/reattach.tsv"

run_capture_with_timeout services-ordinary-up-reattach 90s "$BIN_DIR/bus-services" up --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR"
wait_for_replacement_owner "$CONTROLLER_PID" || die "ordinary up did not leave exactly one replacement renewal owner"
capture_pids "$RESULT_ABS/pids.reattached.tsv"
REATTACHED_SUBSCRIPTION_PID="$(awk -F '\t' '$1 == "subscription" {print $2}' "$RESULT_ABS/pids.reattached.tsv")"
[[ "$REATTACHED_SUBSCRIPTION_PID" == "$SUBSCRIPTION_PID" ]] ||
  die "original subscription process identity changed during ordinary-up reattach: $SUBSCRIPTION_PID -> ${REATTACHED_SUBSCRIPTION_PID:-missing}"
owned_pid_active "$SUBSCRIPTION_PID" || die "original subscription process $SUBSCRIPTION_PID is not active after ordinary-up reattach"
if child_pids_match "$RESULT_ABS/pids.initial.tsv" "$RESULT_ABS/pids.reattached.tsv"; then
  CHILD_PID_RESULT="unchanged"
else
  CHILD_PID_RESULT="changed"
fi
cp "$RESULT_ABS/pids.reattached.tsv" "$RESULT_ABS/pids.initial.tsv"
printf 'controller_after\t%s\nowner_count_after\t1\nchild_pids\t%s\n' "$REPLACEMENT_OWNER_PID" "$CHILD_PID_RESULT" >>"$RESULT_ABS/reattach.tsv"

if [[ "$MODE" == "parent-fail" ]]; then
  [[ -z "$DEGRADED_OWNER_STATUS" ]] || die "parent unexpectedly reported renewal-owner health"
  die "parent RED: renewal-owner degraded health and authenticated ordinary-up reattach are unavailable"
fi

case "$DEGRADED_OWNER_STATUS" in
  missing|exited|wrong_process|inspection_unavailable) ;;
  *) die "candidate did not report truthful degraded renewal-owner health" ;;
esac
[[ "$REPLACEMENT_OWNER_PID" != "$CONTROLLER_PID" ]] || die "replacement renewal owner reused the killed controller PID"
[[ "$CHILD_PID_RESULT" == "unchanged" ]] || die "healthy child PIDs changed during ordinary-up reattach"
run_capture owner-health-after-reattach "$BIN_DIR/bus-services" list --file "$STACK_DIR/services.yml" --state-dir "$STATE_DIR" --format json
[[ "$(jq -r '.renewal_owner.status // empty' "$RESULT_ABS/operations/owner-health-after-reattach.stdout")" == "running" ]] ||
  die "replacement renewal owner did not become truthfully healthy"
printf 'reattach_status\trunning\n' >>"$RESULT_ABS/reattach.tsv"

previous_hash="$READY_HASH"
previous_inode="$READY_INODE"
for rotation in 1 2; do
  wait_for_rotation "$previous_hash" || die "timed out waiting for credential rotation $rotation"
  token_metadata "rotation-$rotation"
  [[ "$WAITED_HASH" == "$TOKEN_HASH" ]] || die "credential changed again while recording rotation $rotation"
  [[ "$TOKEN_HASH" != "$previous_hash" ]] || die "credential rotation $rotation reused the prior token hash"
  [[ "$TOKEN_INODE" != "$previous_inode" ]] || die "credential rotation $rotation did not atomically replace the token inode"
  previous_hash="$TOKEN_HASH"
  previous_inode="$TOKEN_INODE"

  capture_pids "$RESULT_ABS/pids.rotation-$rotation.tsv"
  assert_same_pids "$RESULT_ABS/pids.initial.tsv" "$RESULT_ABS/pids.rotation-$rotation.tsv"

  marker="thread131-rotation-$rotation"
  run_capture "thread-send-$rotation" "$BIN_DIR/bus-thread" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" send "$THREAD_ID" --author thread131-harness "$marker"
  run_capture "thread-show-$rotation" "$BIN_DIR/bus-thread" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" --format json show "$THREAD_ID" --latest 2
  assert_thread_show "thread-show-$rotation" "$THREAD_ID" "$marker"
  wait_for_subscription_marker "$marker" "$THREAD_ID" || die "already-open subscription missed $marker"

  run_capture "worker-status-$rotation" "$BIN_DIR/bus-workers" --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json status "$WORKER_ID" --environment local
  assert_worker_status "worker-status-$rotation" "$WORKER_ID"
  run_capture "worker-message-$rotation" "$BIN_DIR/bus-workers" --api-url "$API_URL" --token-file "$TOKEN_FILE" --format json message "$WORKER_ID" --text "continuity-$rotation" --message-id "thread131-message-$rotation" --environment local
  assert_worker_message "worker-message-$rotation" "$WORKER_ID" "thread131-message-$rotation" "continuity-$rotation"

  repo_id="thread131-rotation-$rotation"
  run_capture "repos-create-$rotation" "$BIN_DIR/bus-events" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" send --name bus.repos.catalog.repo.create.request --payload "{\"id\":\"$repo_id\",\"group\":\"local\",\"name\":\"Thread 131 rotation $rotation\",\"default_branch\":\"main\"}"
  run_capture "repos-init-$rotation" "$BIN_DIR/bus-events" --api-url "$EVENTS_URL" --token-file "$TOKEN_FILE" send --name bus.repos.init.request --payload "{\"repo_id\":\"$repo_id\",\"default_base_ref\":\"main\"}"
  wait_for_repo_materialization "rotation-$rotation" "$repo_id" || die "Repos process did not materialize $repo_id"
done

verify_retained_repositories 1 || die "retained Repos evidence is incomplete or not bare"
audit_retained_artifacts || die "retained artifact audit found credential failure or secret leakage"

FINAL_STATUS="passed"
printf 'PASS credential continuity %s\n' "$MODE"
