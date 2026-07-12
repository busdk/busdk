#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source_script="$root_dir/scripts/bus-services-protected-run"
config="$root_dir/config/services-protected.env"
services="$root_dir/services.yml"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
log="$tmp_dir/log"
bootstrap_args="$tmp_dir/bootstrap.args"
control_file="$tmp_dir/control/cgroup.procs"
command_args="$tmp_dir/command.args"
command_env="$tmp_dir/command.env"
command_pid="$tmp_dir/command.pid"
mkdir -p "$fake_bin" "$(dirname "$control_file")"
cp "$source_script" "$fake_bin/bus-services-protected-run"
chmod 0755 "$fake_bin/bus-services-protected-run"
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

cat >"$fake_bin/stat" <<'SH'
#!/bin/sh
set -eu
[ "$1" = '-c' ] && [ "$#" -eq 3 ]
format=$2
file=$3
case "$file" in
	*/bus-integration-linux) unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	*/runuser) unsafe=${FAKE_UNSAFE_PRIVDROP:-0} ;;
	*) exit 1 ;;
esac
case "$format" in
	%u) if [ "$unsafe" = 2 ]; then printf '1004\n'; else printf '0\n'; fi ;;
	%a) if [ "$unsafe" = 1 ]; then printf '775\n'; else printf '755\n'; fi ;;
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
printf 'unexpected-integration' >>"$FAKE_LOG"
for arg in "$@"; do printf ' <%s>' "$arg" >>"$FAKE_LOG"; done
printf '\n' >>"$FAKE_LOG"
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
shift 2

if [ "${FAKE_PRIVDROP_FAIL:-0}" = 1 ]; then exit 52; fi
if [ "${FAKE_ATTACH_FAIL:-0}" = 1 ]; then
	control="$FAKE_CONTROL_FILE.missing"
else
	control=$(dirname "$FAKE_CONTROL_FILE")
fi
exec sh -ceu "$body" "$zero" "$control" "$@"
SH

cat >"$fake_bin/cat" <<'SH'
#!/bin/sh
set -eu
if [ "${FAKE_READBACK_FAIL:-0}" = 1 ] && [ "$#" -eq 1 ] && [ "$1" = "$FAKE_CONTROL_FILE" ]; then
	exit 63
fi
exec /bin/cat "$@"
SH

cat >"$fake_bin/exec-target" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$@" >"$FAKE_COMMAND_ARGS"
printf '%s\n' "$BUS_SERVICES_PROTECTED" "$BUS_SERVICES_CGROUP_MOUNT" "$BUS_SERVICES_CGROUP_IDENTITY" "$BUS_SERVICES_LINUX_INTEGRATION_BIN" >"$FAKE_COMMAND_ENV"
printf '%s\n' "$$" >"$FAKE_COMMAND_PID"
SH

chmod 0755 "$fake_bin/id" "$fake_bin/stat" "$fake_bin/bus-integration-linux" "$fake_bin/runuser" "$fake_bin/cat" "$fake_bin/exec-target"

run_script() {
	PATH="$fake_bin:$PATH" \
	FAKE_LOG="$log" \
	FAKE_BOOTSTRAP_ARGS="$bootstrap_args" \
	FAKE_CONTROL_FILE="$control_file" \
	FAKE_COMMAND_ARGS="$command_args" \
	FAKE_COMMAND_ENV="$command_env" \
	FAKE_COMMAND_PID="$command_pid" \
	"$fake_bin/bus-services-protected-run" "$@"
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

run_script bus-runtime -- "$fake_bin/exec-target" 'value with spaces' --leading-dash
cmp "$tmp_dir/expected-bootstrap" "$bootstrap_args"
cat >"$tmp_dir/expected-command-args" <<'EOF'
value with spaces
--leading-dash
EOF
cmp "$tmp_dir/expected-command-args" "$command_args"
cmp "$control_file" "$command_pid"
[ "$(wc -l <"$control_file")" -eq 1 ]
cat >"$tmp_dir/expected-command-env" <<EOF
1
/sys/fs/cgroup
bus-services
$fake_bin/bus-integration-linux
EOF
cmp "$tmp_dir/expected-command-env" "$command_env"
test "$(grep -xc 'bootstrap' "$log")" -eq 1
grep -Fq 'privdrop <--user> <bus-runtime> <--> <sh> <-ceu>' "$log"
! grep -q 'work-exec\|unexpected-integration' "$log"

grep -qx 'BUS_SERVICES_PROTECTED=1' <(sed -n '1p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_MOUNT=/sys/fs/cgroup' <(sed -n '2p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_IDENTITY=bus-services' <(sed -n '3p' "$config")
grep -qx 'BUS_SERVICES_LINUX_INTEGRATION_BIN=/home/coding-agent/coding-agent/.local/bin/bus-integration-linux' <(sed -n '4p' "$config")
test "$(wc -l <"$config")" -eq 4
git show 15033d8^:services.yml >"$tmp_dir/expected-services.yml"
cmp "$tmp_dir/expected-services.yml" "$services"

make -C "$root_dir" install DESTDIR="$tmp_dir/install-root" BINDIR=/test/bin
installed_launcher="$tmp_dir/install-root/test/bin/bus-services-protected-run"
[ -f "$installed_launcher" ]
[ "$(stat -c %a "$installed_launcher")" = 755 ]

assert_command_not_run() {
	[ ! -s "$command_args" ]
	[ ! -s "$command_env" ]
	[ ! -s "$command_pid" ]
}

expect_failure_without_bootstrap() {
	: >"$log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_pid"
	set +e
	run_script "$@" >/dev/null 2>&1
	status=$?
	set -e
	[ "$status" -ne 0 ]
	[ ! -e "$bootstrap_args" ]
	assert_command_not_run
}

expect_failure_after_bootstrap() {
	: >"$log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_pid"
	set +e
	run_script "$@" >/dev/null 2>&1
	status=$?
	set -e
	[ "$status" -ne 0 ]
	test "$(grep -xc 'bootstrap' "$log")" -eq 1
	assert_command_not_run
}

expect_failure_without_bootstrap bus-runtime --
FAKE_NONROOT=1 expect_failure_without_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_MISSING_USER=1 expect_failure_without_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_UNSAFE_LINUX=1 expect_failure_without_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_UNSAFE_PRIVDROP=1 expect_failure_without_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_BOOTSTRAP_FAIL=1 expect_failure_after_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_ATTACH_FAIL=1 expect_failure_after_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_READBACK_FAIL=1 expect_failure_after_bootstrap bus-runtime -- "$fake_bin/exec-target"
FAKE_PRIVDROP_FAIL=1 expect_failure_after_bootstrap bus-runtime -- "$fake_bin/exec-target"

! grep -Eq '(^|[[:space:]])(systemctl|systemd-run|sudo)([[:space:]]|$)' "$source_script"
! grep -q 'cgroup work-exec' "$source_script"

printf 'protected Services install/config regression OK\n'
