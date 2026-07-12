#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source_script="$root_dir/scripts/bus-services-protected-run"
config="$root_dir/config/services-protected.env"
services="$root_dir/services.yml"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# The disposable launcher changes only the fixed host utility paths after the
# production source has asserted them. Production has no test-time tool root.
grep -Fxq 'PATH=/usr/sbin:/usr/bin:/sbin:/bin' "$source_script"
grep -Fxq 'id_bin=/usr/bin/id' "$source_script"
grep -Fxq 'stat_bin=/usr/bin/stat' "$source_script"
grep -Fxq 'readlink_bin=/usr/bin/readlink' "$source_script"
grep -Fxq 'privdrop_bin=/usr/sbin/runuser' "$source_script"
grep -Fxq 'launcher_path=$0' "$source_script"
grep -Fxq 'linux_bin=$launcher_dir/bus-integration-linux' "$source_script"
grep -Fq '*/.local/bin/*|*/scripts/bus-services-protected-run)' "$source_script"
! grep -Eq '(TEST|FAKE|TOOL_ROOT|PATH_OVERRIDE)' "$source_script"
! grep -Eq 'command -v|dirname|cat "?\$control_path/cgroup\.procs' "$source_script"
grep -Fxq 'IFS= read -r attached_pid <"$control_path/cgroup.procs" || exit 1' "$source_script"

fake_bin="$tmp_dir/fixed-tools"
poison_bin="$tmp_dir/path-injection"
log="$tmp_dir/log"
bootstrap_args="$tmp_dir/bootstrap.args"
control_file="$tmp_dir/control/cgroup.procs"
command_args="$tmp_dir/command.args"
command_env="$tmp_dir/command.env"
command_pid="$tmp_dir/command.pid"
test_script="$fake_bin/bus-services-protected-run"
launcher_under_test=$test_script
mkdir -p "$fake_bin" "$poison_bin" "$(dirname "$control_file")"
: >"$control_file"

sed \
	-e "s|^id_bin=/usr/bin/id$|id_bin=$fake_bin/id|" \
	-e "s|^stat_bin=/usr/bin/stat$|stat_bin=$fake_bin/stat|" \
	-e "s|^readlink_bin=/usr/bin/readlink$|readlink_bin=$fake_bin/readlink|" \
	-e "s|^privdrop_bin=/usr/sbin/runuser$|privdrop_bin=$fake_bin/runuser|" \
	"$source_script" >"$test_script"
chmod 0755 "$test_script"

cat >"$fake_bin/id" <<'SH'
#!/bin/sh
set -eu
printf 'fixed-id' >>"$FAKE_LOG"
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
[ "$1" = '-c' ] && [ "$3" = '--' ] && [ "$#" -eq 4 ]
format=$2
path=$4
unsafe=0
case "$path" in
	/|/usr|/usr/local|/usr/sbin) kind=directory ;;
	/usr/local/bin) kind=directory; unsafe=${FAKE_UNSAFE_LAUNCHER_DIR:-0} ;;
	/usr/local/bin/bus-services-protected-run) kind='regular file'; unsafe=${FAKE_UNSAFE_LAUNCHER:-0} ;;
	/usr/local/bin/bus-integration-linux) kind='regular file'; unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	"$FAKE_FIXED_TOOLS") kind=directory; unsafe=${FAKE_UNSAFE_LAUNCHER_DIR:-0} ;;
	"$FAKE_FIXED_TOOLS"/bus-services-protected-run) kind='regular file'; unsafe=${FAKE_UNSAFE_LAUNCHER:-0} ;;
	"$FAKE_FIXED_TOOLS"/bus-integration-linux) kind='regular file'; unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	"$FAKE_FIXED_TOOLS"/runuser) kind='regular file'; unsafe=${FAKE_UNSAFE_PRIVDROP:-0} ;;
	/tmp|/tmp/*) kind=directory ;;
	*) exit 1 ;;
esac

if { [ "$path" = /usr/local ] || [ "$path" = "${FAKE_FIXED_TOOLS%/*}" ]; } && [ "${FAKE_UNSAFE_LAUNCHER_PARENT:-0}" != 0 ]; then
	unsafe=$FAKE_UNSAFE_LAUNCHER_PARENT
fi
case "$format" in
	%F) if [ "$unsafe" = 4 ]; then printf 'directory\n'; else printf '%s\n' "$kind"; fi ;;
	%u) if [ "$unsafe" = 2 ]; then printf '1004\n'; else printf '0\n'; fi ;;
	%a) if [ "$unsafe" = 1 ]; then printf '775\n'; else printf '755\n'; fi ;;
	*) exit 1 ;;
esac
printf 'fixed-stat <%s> <%s>\n' "$format" "$path" >>"$FAKE_LOG"
SH

cat >"$fake_bin/readlink" <<'SH'
#!/bin/sh
set -eu
[ "$1" = '--' ] && [ "$#" -eq 2 ]
path=$2
printf 'fixed-readlink <%s>\n' "$path" >>"$FAKE_LOG"
case "$path" in
	/usr/local/bin/bus-services-protected-run) [ "${FAKE_SYMLINK_LAUNCHER:-0}" = 1 ] || exit 1 ;;
	/usr/local/bin/bus-integration-linux) [ "${FAKE_SYMLINK_LINUX:-0}" = 1 ] || exit 1 ;;
	"$FAKE_FIXED_TOOLS"/bus-services-protected-run) [ "${FAKE_SYMLINK_LAUNCHER:-0}" = 1 ] || exit 1 ;;
	"$FAKE_FIXED_TOOLS"/bus-integration-linux) [ "${FAKE_SYMLINK_LINUX:-0}" = 1 ] || exit 1 ;;
	*) exit 1 ;;
esac
printf '/unsafe/link-target\n'
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

[ "$1" = '--user' ] && [ "$3" = '--' ] && [ "$4" = /bin/sh ] && [ "$5" = -ceu ]
body=$6
shift 6
zero=$1
shift 2

if [ "${FAKE_PRIVDROP_FAIL:-0}" = 1 ]; then exit 52; fi
if [ "${FAKE_ATTACH_FAIL:-0}" = 1 ]; then
	control="$FAKE_CONTROL_FILE.missing"
else
	control=${FAKE_CONTROL_FILE%/*}
fi
exec /bin/sh -ceu "$body" "$zero" "$control" "$@"
SH

cat >"$fake_bin/exec-target" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$@" >"$FAKE_COMMAND_ARGS"
printf '%s\n' "$BUS_SERVICES_PROTECTED" "$BUS_SERVICES_CGROUP_MOUNT" "$BUS_SERVICES_CGROUP_IDENTITY" "$BUS_SERVICES_LINUX_INTEGRATION_BIN" >"$FAKE_COMMAND_ENV"
printf '%s\n' "$$" >"$FAKE_COMMAND_PID"
SH

for helper in id stat readlink runuser dirname cat sh; do
	cat >"$poison_bin/$helper" <<'SH'
#!/bin/sh
printf 'path-injection <%s>\n' "$0" >>"$FAKE_LOG"
exit 99
SH
	chmod 0755 "$poison_bin/$helper"
done
chmod 0755 "$fake_bin/id" "$fake_bin/stat" "$fake_bin/readlink" "$fake_bin/bus-integration-linux" "$fake_bin/runuser" "$fake_bin/exec-target"

run_script() {
	PATH="$poison_bin:$PATH" \
	FAKE_LOG="$log" \
	FAKE_FIXED_TOOLS="$fake_bin" \
	FAKE_BOOTSTRAP_ARGS="$bootstrap_args" \
	FAKE_CONTROL_FILE="$control_file" \
	FAKE_COMMAND_ARGS="$command_args" \
	FAKE_COMMAND_ENV="$command_env" \
	FAKE_COMMAND_PID="$command_pid" \
	FAKE_NONROOT="${FAKE_NONROOT:-0}" \
	FAKE_MISSING_USER="${FAKE_MISSING_USER:-0}" \
	FAKE_UNSAFE_LAUNCHER="${FAKE_UNSAFE_LAUNCHER:-0}" \
	FAKE_UNSAFE_LAUNCHER_DIR="${FAKE_UNSAFE_LAUNCHER_DIR:-0}" \
	FAKE_UNSAFE_LAUNCHER_PARENT="${FAKE_UNSAFE_LAUNCHER_PARENT:-0}" \
	FAKE_UNSAFE_LINUX="${FAKE_UNSAFE_LINUX:-0}" \
	FAKE_UNSAFE_PRIVDROP="${FAKE_UNSAFE_PRIVDROP:-0}" \
	FAKE_SYMLINK_LAUNCHER="${FAKE_SYMLINK_LAUNCHER:-0}" \
	FAKE_SYMLINK_LINUX="${FAKE_SYMLINK_LINUX:-0}" \
	FAKE_BOOTSTRAP_FAIL="${FAKE_BOOTSTRAP_FAIL:-0}" \
	FAKE_ATTACH_FAIL="${FAKE_ATTACH_FAIL:-0}" \
	FAKE_PRIVDROP_FAIL="${FAKE_PRIVDROP_FAIL:-0}" \
	"$launcher_under_test" "$@"
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
grep -Fq 'fixed-id <-u>' "$log"
grep -Fq "fixed-stat <%F> <$fake_bin/bus-services-protected-run>" "$log"
grep -Fq "fixed-readlink <$fake_bin/bus-services-protected-run>" "$log"
grep -Fq 'privdrop <--user> <bus-runtime> <--> </bin/sh> <-ceu>' "$log"
! grep -q 'path-injection\|work-exec\|unexpected-integration' "$log"

grep -qx 'BUS_SERVICES_PROTECTED=1' <(sed -n '1p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_MOUNT=/sys/fs/cgroup' <(sed -n '2p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_IDENTITY=bus-services' <(sed -n '3p' "$config")
grep -qx 'BUS_SERVICES_LINUX_INTEGRATION_BIN=/usr/local/bin/bus-integration-linux' <(sed -n '4p' "$config")
test "$(wc -l <"$config")" -eq 4
git show d109f1b:services.yml >"$tmp_dir/expected-services.yml"
cmp "$tmp_dir/expected-services.yml" "$services"

make -C "$root_dir" -n install DESTDIR="$tmp_dir/install-root" BINDIR=/test/bin >"$tmp_dir/install-dry-run"
grep -Fq 'scripts/bus-services-protected-run' "$tmp_dir/install-dry-run"
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
	setting=$1
	shift
	if [ -n "$setting" ]; then export "$setting"; fi
	: >"$log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_pid"
	set +e
	run_script "$@" >/dev/null 2>&1
	status=$?
	set -e
	[ "$status" -ne 0 ]
	[ ! -e "$bootstrap_args" ]
	assert_command_not_run
	if [ -n "$setting" ]; then unset "${setting%%=*}"; fi
}

expect_failure_after_bootstrap() {
	setting=$1
	shift
	if [ -n "$setting" ]; then export "$setting"; fi
	: >"$log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_pid"
	set +e
	run_script "$@" >/dev/null 2>&1
	status=$?
	set -e
	[ "$status" -ne 0 ]
	test "$(grep -xc 'bootstrap' "$log")" -eq 1
	assert_command_not_run
	if [ -n "$setting" ]; then unset "${setting%%=*}"; fi
}

expect_failure_without_bootstrap '' bus-runtime --
source_launcher="$tmp_dir/source-checkout/scripts/bus-services-protected-run"
local_launcher="$tmp_dir/home/.local/bin/bus-services-protected-run"
mkdir -p "${source_launcher%/*}" "${local_launcher%/*}"
cp "$test_script" "$source_launcher"
cp "$test_script" "$local_launcher"
chmod 0755 "$source_launcher" "$local_launcher"
launcher_under_test=$source_launcher
expect_failure_without_bootstrap '' bus-runtime -- "$fake_bin/exec-target"
launcher_under_test=$local_launcher
expect_failure_without_bootstrap '' bus-runtime -- "$fake_bin/exec-target"
launcher_under_test=$test_script
expect_failure_without_bootstrap FAKE_NONROOT=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_MISSING_USER=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LAUNCHER=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LAUNCHER=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_SYMLINK_LAUNCHER=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LAUNCHER_DIR=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LAUNCHER_DIR=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LAUNCHER_PARENT=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LINUX=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_LINUX=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_SYMLINK_LINUX=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_PRIVDROP=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_PRIVDROP=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_BOOTSTRAP_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_ATTACH_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_PRIVDROP_FAIL=1 bus-runtime -- "$fake_bin/exec-target"

! grep -Eq '(^|[[:space:]])(systemctl|systemd-run|sudo)([[:space:]]|$)' "$source_script"
! grep -q 'cgroup work-exec' "$source_script"

printf 'protected Services install/config regression OK\n'
