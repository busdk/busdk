#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
script="$root_dir/scripts/bus-services-protected-run"
config="$root_dir/config/services-protected.env"
services="$root_dir/services.yml"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
log="$tmp_dir/log"
bootstrap_args="$tmp_dir/bootstrap.args"
work_args="$tmp_dir/work.args"
control_file="$tmp_dir/control/cgroup.procs"
mkdir -p "$fake_bin" "$(dirname "$control_file")"
: >"$control_file"

cat >"$fake_bin/id" <<'SH'
#!/bin/sh
set -eu
printf 'id' >>"$FAKE_LOG"
for arg in "$@"; do printf ' <%s>' "$arg" >>"$FAKE_LOG"; done
printf '\n' >>"$FAKE_LOG"

if [ "$1" = '-u' ] && [ "$#" -eq 1 ]; then
	if [ "${FAKE_NONROOT:-0}" = 1 ]; then printf '1000\n'; else printf '0\n'; fi
	exit 0
fi
if [ "${FAKE_MISSING_USER:-0}" = 1 ]; then exit 1; fi
case "$1:$2" in
	-u:bus-runtime) printf '1004\n' ;;
	-g:bus-runtime) printf '1005\n' ;;
	*) exit 1 ;;
esac
SH

cat >"$fake_bin/bus-integration-linux" <<'SH'
#!/bin/sh
set -eu
if [ "$1" = cgroup ] && [ "$2" = bootstrap ]; then
	printf 'bootstrap\n' >>"$FAKE_LOG"
	printf '%s\n' "$@" >"$FAKE_BOOTSTRAP_ARGS"
	if [ "${FAKE_BOOTSTRAP_FAIL:-0}" = 1 ]; then exit 41; fi
	exit 0
fi
if [ "$1" = cgroup ] && [ "$2" = work-exec ]; then
	[ -s "$FAKE_CONTROL_FILE" ] || exit 70
	printf 'work-exec\n' >>"$FAKE_LOG"
	printf '%s\n' "$@" >"$FAKE_WORK_ARGS"
	exit 0
fi
exit 71
SH

cat >"$fake_bin/runuser" <<'SH'
#!/bin/sh
set -eu
printf 'privdrop' >>"$FAKE_LOG"
for arg in "$@"; do printf ' <%s>' "$arg" >>"$FAKE_LOG"; done
printf '\n' >>"$FAKE_LOG"

[ "$1" = '--user' ] && [ "$3" = '--' ] && [ "$4" = sh ] && [ "$5" = -ceu ]
body=$6
shift 6
zero=$1
linux_bin=$3
mount_path=$4
domain=$5
shift 5

if [ "${FAKE_ATTACH_FAIL:-0}" = 1 ]; then
	control="$FAKE_CONTROL_FILE.missing"
else
	control=$(dirname "$FAKE_CONTROL_FILE")
fi

exec sh -ceu "$body" "$zero" "$control" "$linux_bin" "$mount_path" "$domain" "$@"
SH

chmod +x "$fake_bin/id" "$fake_bin/bus-integration-linux" "$fake_bin/runuser"

run_script() {
	PATH="$fake_bin:$PATH" \
	FAKE_LOG="$log" \
	FAKE_BOOTSTRAP_ARGS="$bootstrap_args" \
	FAKE_WORK_ARGS="$work_args" \
	FAKE_CONTROL_FILE="$control_file" \
	"$script" "$@"
}

cat >"$tmp_dir/expected-bootstrap" <<'EOF'
cgroup
bootstrap
--mount-path
/sys/fs/cgroup
--domain
bus-services
--uid
1004
--gid
1005
--work-memory-high
21474836480
--work-memory-max
25769803776
--work-swap-max
0
--work-cpu-weight
50
--work-pids-max
4096
--control-memory-min
2147483648
--control-memory-low
4294967296
--control-cpu-weight
200
EOF

run_script bus-runtime -- /bin/echo 'value with spaces' --leading-dash
cmp "$tmp_dir/expected-bootstrap" "$bootstrap_args"
cat >"$tmp_dir/expected-work" <<'EOF'
cgroup
work-exec
--mount-path
/sys/fs/cgroup
--identity
bus-services
--class
light
--
/bin/echo
value with spaces
--leading-dash
EOF
cmp "$tmp_dir/expected-work" "$work_args"
[ -s "$control_file" ]
test "$(grep -xc 'bootstrap' "$log")" -eq 1
grep -qx 'bootstrap' <(sed -n '4p' "$log")
grep -Fq 'privdrop <--user> <bus-runtime> <--> <sh> <-ceu>' "$log"
grep -qx 'work-exec' <(tail -n 1 "$log")
grep -qx 'BUS_SERVICES_PROTECTED=1' <(sed -n '1p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_MOUNT=/sys/fs/cgroup' <(sed -n '2p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_IDENTITY=bus-services' <(sed -n '3p' "$config")
test "$(wc -l <"$config")" -eq 3
grep -A2 '^env_files:' "$services" | grep -qx '  - config/services-protected.env'

expect_failure_without_bootstrap() {
	: >"$log"
	rm -f "$bootstrap_args" "$work_args"
	set +e
	run_script "$@" >/dev/null 2>&1
	status=$?
	set -e
	[ "$status" -ne 0 ]
	[ ! -e "$bootstrap_args" ]
}

expect_failure_without_bootstrap bus-runtime --
FAKE_NONROOT=1 expect_failure_without_bootstrap bus-runtime -- /bin/true
FAKE_MISSING_USER=1 expect_failure_without_bootstrap bus-runtime -- /bin/true

: >"$log"
rm -f "$work_args"
set +e
FAKE_BOOTSTRAP_FAIL=1 run_script bus-runtime -- /bin/true >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
test "$(grep -xc 'bootstrap' "$log")" -eq 1
[ ! -e "$work_args" ]

: >"$log"
rm -f "$work_args"
set +e
FAKE_ATTACH_FAIL=1 run_script bus-runtime -- /bin/true >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
test "$(grep -xc 'bootstrap' "$log")" -eq 1
grep -qx 'bootstrap' <(sed -n '4p' "$log")
[ ! -e "$work_args" ]

! grep -Eq '(^|[[:space:]])(systemctl|systemd-run|sudo)([[:space:]]|$)' "$script"

printf 'protected Services install/config regression OK\n'
