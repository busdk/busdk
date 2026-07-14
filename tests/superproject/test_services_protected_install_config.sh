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
grep -Fxq 'mkdir_bin=/usr/bin/mkdir' "$source_script" || {
	printf '%s\n' 'missing trusted protected runtime bootstrap in launcher' >&2
	exit 1
}
grep -Fxq 'chown_bin=/usr/bin/chown' "$source_script"
grep -Fxq 'chmod_bin=/usr/bin/chmod' "$source_script"
grep -Fxq 'mv_bin=/usr/bin/mv' "$source_script"
grep -Fxq 'privdrop_bin=/usr/sbin/runuser' "$source_script"
grep -Fxq 'runtime_dir=/run/busdk' "$source_script"
grep -Fxq 'heavy_lock_path=$runtime_dir/heavy.lock' "$source_script"
grep -Fxq 'protected_env_path=$runtime_dir/services-protected.env' "$source_script"
grep -Fxq 'protected_env_source=$launcher_dir/bus-services-protected.env' "$source_script"
grep -Fxq 'launcher_path=$0' "$source_script"
grep -Fxq 'linux_bin=$launcher_dir/bus-integration-linux' "$source_script"
grep -Fq '*/.local/bin/*|*/scripts/bus-services-protected-run)' "$source_script"
! grep -Eq '(TEST|FAKE|TOOL_ROOT|PATH_OVERRIDE)' "$source_script"
! grep -Eq 'command -v|dirname|cat "?\$control_path/cgroup\.procs' "$source_script"
grep -Fxq 'IFS= read -r attached_pid <"$control_path/cgroup.procs" || exit 1' "$source_script"
grep -Fxq 'if protected_stack_command "$@"; then' "$source_script"
grep -Fq 'exec "$@" --env-file "$protected_env_path"' "$source_script"

fake_bin="$tmp_dir/fixed-tools"
poison_bin="$tmp_dir/path-injection"
log="$tmp_dir/log"
phase_log="$tmp_dir/phases"
bootstrap_args="$tmp_dir/bootstrap.args"
control_file="$tmp_dir/control/cgroup.procs"
command_args="$tmp_dir/command.args"
command_env="$tmp_dir/command.env"
command_env_file="$tmp_dir/command.env-file"
command_pid="$tmp_dir/command.pid"
runtime_dir="$tmp_dir/run/busdk"
heavy_lock_path="$runtime_dir/heavy.lock"
protected_env_path="$runtime_dir/services-protected.env"
test_script="$fake_bin/bus-services-protected-run"
launcher_under_test=$test_script
mkdir -p "$fake_bin" "$poison_bin" "$(dirname "$control_file")" "${runtime_dir%/*}"
: >"$control_file"

write_test_launcher() {
	launcher_source=$1
	launcher_target=$2
	sed \
		-e "s|^id_bin=/usr/bin/id$|id_bin=$fake_bin/id|" \
		-e "s|^stat_bin=/usr/bin/stat$|stat_bin=$fake_bin/stat|" \
		-e "s|^readlink_bin=/usr/bin/readlink$|readlink_bin=$fake_bin/readlink|" \
		-e "s|^mkdir_bin=/usr/bin/mkdir$|mkdir_bin=$fake_bin/mkdir|" \
		-e "s|^chown_bin=/usr/bin/chown$|chown_bin=$fake_bin/chown|" \
		-e "s|^chmod_bin=/usr/bin/chmod$|chmod_bin=$fake_bin/chmod|" \
		-e "s|^mv_bin=/usr/bin/mv$|mv_bin=$fake_bin/mv|" \
		-e "s|^privdrop_bin=/usr/sbin/runuser$|privdrop_bin=$fake_bin/runuser|" \
		-e "s|^runtime_dir=/run/busdk$|runtime_dir=$runtime_dir|" \
		"$launcher_source" >"$launcher_target"
	chmod 0755 "$launcher_target"
}

write_test_launcher "$source_script" "$test_script"
/usr/bin/cp "$config" "$fake_bin/bus-services-protected.env"

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
	-u:bus-runtime)
		if [ "${FAKE_ROOT_UID:-0}" = 1 ]; then
			printf '0\n'
		else
			printf '1004\n'
		fi
		;;
	-g:bus-runtime)
		if [ "${FAKE_ROOT_GID:-0}" = 1 ]; then
			printf '0\n'
		else
			printf '1005\n'
		fi
		;;
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
owner=0
group=0
mode=755
case "$path" in
	/|/usr|/usr/local|/usr/sbin) kind=directory ;;
	/usr/local/bin) kind=directory; unsafe=${FAKE_UNSAFE_LAUNCHER_DIR:-0} ;;
	/usr/local/bin/bus-services-protected-run) kind='regular file'; unsafe=${FAKE_UNSAFE_LAUNCHER:-0} ;;
	/usr/local/bin/bus-integration-linux) kind='regular file'; unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	"$FAKE_FIXED_TOOLS") kind=directory; unsafe=${FAKE_UNSAFE_LAUNCHER_DIR:-0} ;;
	"$FAKE_FIXED_TOOLS"/bus-services-protected-run) kind='regular file'; unsafe=${FAKE_UNSAFE_LAUNCHER:-0} ;;
	"$FAKE_FIXED_TOOLS"/bus-integration-linux) kind='regular file'; unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	"$FAKE_FIXED_TOOLS"/bus-services-protected.env) kind='regular file'; mode=644; unsafe=${FAKE_UNSAFE_PROTECTED_SOURCE:-0} ;;
	"$FAKE_FIXED_TOOLS"/runuser) kind='regular file'; unsafe=${FAKE_UNSAFE_PRIVDROP:-0} ;;
	"$FAKE_FIXED_TOOLS"/mkdir) kind='regular file'; unsafe=${FAKE_UNSAFE_MKDIR:-0} ;;
	"$FAKE_FIXED_TOOLS"/chown) kind='regular file'; unsafe=${FAKE_UNSAFE_CHOWN:-0} ;;
	"$FAKE_FIXED_TOOLS"/chmod) kind='regular file'; unsafe=${FAKE_UNSAFE_CHMOD:-0} ;;
	"$FAKE_FIXED_TOOLS"/mv) kind='regular file'; unsafe=${FAKE_UNSAFE_MV:-0} ;;
	"$FAKE_LAUNCHER_DIR") kind=directory; unsafe=${FAKE_UNSAFE_LAUNCHER_DIR:-0} ;;
	"$FAKE_LAUNCHER_DIR"/bus-services-protected-run) kind='regular file'; unsafe=${FAKE_UNSAFE_LAUNCHER:-0} ;;
	"$FAKE_LAUNCHER_DIR"/bus-integration-linux) kind='regular file'; unsafe=${FAKE_UNSAFE_LINUX:-0} ;;
	"$FAKE_LAUNCHER_DIR"/bus-services-protected.env) kind='regular file'; mode=644; unsafe=${FAKE_UNSAFE_PROTECTED_SOURCE:-0} ;;
	"${FAKE_RUNTIME_DIR%/*}") kind=directory; unsafe=${FAKE_UNSAFE_RUNTIME_PARENT:-0} ;;
	"$FAKE_RUNTIME_DIR")
		[ -e "$path" ] || exit 1
		kind=directory
		unsafe=${FAKE_UNSAFE_RUNTIME_DIR:-0}
		;;
	"$FAKE_HEAVY_LOCK")
		[ -e "$path" ] || exit 1
		kind='regular file'
		owner=1004
		group=1005
		mode=600
		unsafe=${FAKE_UNSAFE_HEAVY_LOCK:-0}
		;;
	"$FAKE_PROTECTED_ENV")
		[ -e "$path" ] || exit 1
		kind='regular file'
		owner=1004
		group=1005
		mode=600
		unsafe=${FAKE_UNSAFE_PROTECTED_ENV:-0}
		;;
	"$FAKE_RUNTIME_DIR"/.services-protected.env.*)
		[ -e "$path" ] || exit 1
		kind='regular file'
		owner=1004
		group=1005
		mode=600
		;;
	/tmp|/tmp/*) kind=directory ;;
	*) exit 1 ;;
esac

if { [ "$path" = /usr/local ] || [ "$path" = "${FAKE_FIXED_TOOLS%/*}" ]; } && [ "${FAKE_UNSAFE_LAUNCHER_PARENT:-0}" != 0 ]; then
	unsafe=$FAKE_UNSAFE_LAUNCHER_PARENT
fi
case "$unsafe" in
	0) ;;
	1)
		case "$mode" in
			600) mode=640 ;;
			644) mode=666 ;;
			*) mode=775 ;;
		esac
		;;
	2) if [ "$owner" = 0 ]; then owner=1004; else owner=0; fi ;;
	3) if [ "$group" = 0 ]; then group=1005; else group=0; fi ;;
	4) if [ "$kind" = directory ]; then kind='regular file'; else kind=directory; fi ;;
	*) exit 1 ;;
esac
case "$format" in
	%F) printf '%s\n' "$kind" ;;
	%u) printf '%s\n' "$owner" ;;
	%g) printf '%s\n' "$group" ;;
	%a) printf '%s\n' "$mode" ;;
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
	"$FAKE_FIXED_TOOLS"/bus-services-protected.env) [ "${FAKE_SYMLINK_PROTECTED_SOURCE:-0}" = 1 ] || exit 1 ;;
	"$FAKE_LAUNCHER_DIR"/bus-services-protected-run) [ "${FAKE_SYMLINK_LAUNCHER:-0}" = 1 ] || exit 1 ;;
	"$FAKE_LAUNCHER_DIR"/bus-integration-linux) [ "${FAKE_SYMLINK_LINUX:-0}" = 1 ] || exit 1 ;;
	"$FAKE_LAUNCHER_DIR"/bus-services-protected.env) [ "${FAKE_SYMLINK_PROTECTED_SOURCE:-0}" = 1 ] || exit 1 ;;
	"$FAKE_RUNTIME_DIR") [ "${FAKE_SYMLINK_RUNTIME_DIR:-0}" = 1 ] || exit 1 ;;
	"$FAKE_HEAVY_LOCK") [ "${FAKE_SYMLINK_HEAVY_LOCK:-0}" = 1 ] || exit 1 ;;
	"$FAKE_PROTECTED_ENV") [ "${FAKE_SYMLINK_PROTECTED_ENV:-0}" = 1 ] || exit 1 ;;
	*) exit 1 ;;
esac
printf '/unsafe/link-target\n'
SH

cat >"$fake_bin/mkdir" <<'SH'
#!/bin/sh
set -eu
printf 'fixed-mkdir' >>"$FAKE_LOG"
for arg in "$@"; do
	printf ' <%s>' "$arg" >>"$FAKE_LOG"
	target=$arg
done
printf '\n' >>"$FAKE_LOG"
[ "${FAKE_MKDIR_FAIL:-0}" = 0 ] || exit 61
[ "$target" = "$FAKE_RUNTIME_DIR" ] || exit 1
printf 'create-runtime-parent\n' >>"$FAKE_PHASE_LOG"
exec /usr/bin/mkdir "$@"
SH

cat >"$fake_bin/chown" <<'SH'
#!/bin/sh
set -eu
printf 'fixed-chown' >>"$FAKE_LOG"
for arg in "$@"; do
	printf ' <%s>' "$arg" >>"$FAKE_LOG"
	target=$arg
done
printf '\n' >>"$FAKE_LOG"
[ "${FAKE_CHOWN_FAIL:-0}" = 0 ] || exit 62
case "$target" in
	"$FAKE_RUNTIME_DIR") expected_owner=0:0; phase=chown-runtime-parent-root ;;
	"$FAKE_HEAVY_LOCK") expected_owner=1004:1005; phase=chown-heavy-lock ;;
	"$FAKE_RUNTIME_DIR"/.services-protected.env.*) expected_owner=1004:1005; phase=chown-protected-env ;;
	*) exit 1 ;;
esac
[ "$#" -eq 3 ] && [ "$1" = "$expected_owner" ] && [ "$2" = -- ] || exit 1
printf '%s\n' "$phase" >>"$FAKE_PHASE_LOG"
SH

cat >"$fake_bin/chmod" <<'SH'
#!/bin/sh
set -eu
printf 'fixed-chmod' >>"$FAKE_LOG"
for arg in "$@"; do
	printf ' <%s>' "$arg" >>"$FAKE_LOG"
	target=$arg
done
printf '\n' >>"$FAKE_LOG"
[ "${FAKE_CHMOD_FAIL:-0}" = 0 ] || exit 63
case "$target" in
	"$FAKE_RUNTIME_DIR") expected_mode=0755; phase=chmod-runtime-parent-root ;;
	"$FAKE_HEAVY_LOCK") expected_mode=0600; phase=chmod-heavy-lock ;;
	"$FAKE_RUNTIME_DIR"/.services-protected.env.*) expected_mode=0600; phase=chmod-protected-env ;;
	*) exit 1 ;;
esac
[ "$#" -eq 3 ] && [ "$1" = "$expected_mode" ] && [ "$2" = -- ] || exit 1
printf '%s\n' "$phase" >>"$FAKE_PHASE_LOG"
exec /usr/bin/chmod "$@"
SH

cat >"$fake_bin/mv" <<'SH'
#!/bin/sh
set -eu
printf 'fixed-mv' >>"$FAKE_LOG"
for arg in "$@"; do printf ' <%s>' "$arg" >>"$FAKE_LOG"; done
printf '\n' >>"$FAKE_LOG"
[ "${FAKE_MV_FAIL:-0}" = 0 ] || exit 64
[ "$#" -eq 3 ] && [ "$1" = -- ] && [ "$3" = "$FAKE_PROTECTED_ENV" ] || exit 1
case "$2" in "$FAKE_RUNTIME_DIR"/.services-protected.env.*) ;; *) exit 1 ;; esac
printf 'publish-protected-env\n' >>"$FAKE_PHASE_LOG"
exec /usr/bin/mv "$@"
SH

cat >"$fake_bin/sh" <<'SH'
#!/bin/sh
set -eu

[ "$1" = -ceu ] || exit 1
body=$2
shift 2
zero=$1
shift
control_path=$1
shift
control_file=$control_path/cgroup.procs

if [ "${FAKE_CONTROL_READ_FAIL:-0}" = 1 ]; then
	rm -f "$control_file"
	touch "$control_file"
	chmod 200 "$control_file"
elif [ "${FAKE_CONTROL_MISMATCH_PID:-0}" = 1 ]; then
	rm -f "$control_file"
	mkfifo "$control_file"
	(
		IFS= read -r attached_pid <"$control_file" || exit 1
		printf '0\n' >"$control_file"
	) &
	control_hook=$!
fi

status=0
/bin/sh -ceu "$body" "$zero" "$control_path" "$@" || status=$?
if [ "${FAKE_CONTROL_READ_FAIL:-0}" = 1 ]; then
	rm -f "$control_file"
elif [ -n "${control_hook:-}" ]; then
	wait "$control_hook" || :
	rm -f "$control_file"
fi
exit "$status"
SH

cat >"$fake_bin/bus-integration-linux" <<'SH'
#!/bin/sh
set -eu
if [ "$1" = cgroup ] && [ "$2" = bootstrap ]; then
	printf 'bootstrap\n' >>"$FAKE_LOG"
	printf 'bootstrap\n' >>"$FAKE_PHASE_LOG"
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
printf 'privdrop\n' >>"$FAKE_PHASE_LOG"

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
exec "$FAKE_FIXED_TOOLS/sh" -ceu "$body" "$zero" "$control" "$@"
SH

cat >"$fake_bin/exec-target" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$@" >"$FAKE_COMMAND_ARGS"
printf '%s\n' "$$" >"$FAKE_COMMAND_PID"
printf 'arbitrary-command\n' >>"$FAKE_PHASE_LOG"
SH

cat >"$fake_bin/stack-target" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$@" >"$FAKE_COMMAND_ARGS"
env_file=
while [ "$#" -gt 0 ]; do
	if [ "$1" = --env-file ]; then
		[ "$#" -ge 2 ] || exit 1
		env_file=$2
		shift 2
		continue
	fi
	shift
done
[ -n "$env_file" ]
printf '%s\n' "$env_file" >"$FAKE_COMMAND_ENV_FILE"
while IFS= read -r line || [ -n "$line" ]; do
	printf '%s\n' "$line"
done <"$env_file" >"$FAKE_COMMAND_ENV"
printf '%s\n' "$$" >"$FAKE_COMMAND_PID"
printf 'stack-command\n' >>"$FAKE_PHASE_LOG"
SH

/usr/bin/cp "$fake_bin/stack-target" "$fake_bin/bus-services"
/usr/bin/cp "$fake_bin/stack-target" "$fake_bin/bus-integration-services"

for helper in id stat readlink mkdir chown chmod mv runuser dirname cat sh; do
	cat >"$poison_bin/$helper" <<'SH'
#!/bin/sh
printf 'path-injection <%s>\n' "$0" >>"$FAKE_LOG"
exit 99
SH
	chmod 0755 "$poison_bin/$helper"
done
chmod 0755 "$fake_bin/id" "$fake_bin/stat" "$fake_bin/readlink" "$fake_bin/mkdir" "$fake_bin/chown" "$fake_bin/chmod" "$fake_bin/mv" "$fake_bin/sh" "$fake_bin/bus-integration-linux" "$fake_bin/runuser" "$fake_bin/exec-target" "$fake_bin/stack-target" "$fake_bin/bus-services" "$fake_bin/bus-integration-services"

run_script() {
	PATH="$poison_bin:$PATH" \
	FAKE_LOG="$log" \
	FAKE_PHASE_LOG="$phase_log" \
	FAKE_FIXED_TOOLS="$fake_bin" \
	FAKE_LAUNCHER_DIR="${launcher_under_test%/*}" \
	FAKE_RUNTIME_DIR="$runtime_dir" \
	FAKE_HEAVY_LOCK="$heavy_lock_path" \
	FAKE_PROTECTED_ENV="$protected_env_path" \
	FAKE_BOOTSTRAP_ARGS="$bootstrap_args" \
	FAKE_CONTROL_FILE="$control_file" \
	FAKE_COMMAND_ARGS="$command_args" \
	FAKE_COMMAND_ENV="$command_env" \
	FAKE_COMMAND_ENV_FILE="$command_env_file" \
	FAKE_COMMAND_PID="$command_pid" \
	FAKE_NONROOT="${FAKE_NONROOT:-0}" \
	FAKE_MISSING_USER="${FAKE_MISSING_USER:-0}" \
	FAKE_UNSAFE_LAUNCHER="${FAKE_UNSAFE_LAUNCHER:-0}" \
	FAKE_UNSAFE_LAUNCHER_DIR="${FAKE_UNSAFE_LAUNCHER_DIR:-0}" \
	FAKE_UNSAFE_LAUNCHER_PARENT="${FAKE_UNSAFE_LAUNCHER_PARENT:-0}" \
	FAKE_UNSAFE_LINUX="${FAKE_UNSAFE_LINUX:-0}" \
	FAKE_UNSAFE_PRIVDROP="${FAKE_UNSAFE_PRIVDROP:-0}" \
	FAKE_UNSAFE_MKDIR="${FAKE_UNSAFE_MKDIR:-0}" \
	FAKE_UNSAFE_CHOWN="${FAKE_UNSAFE_CHOWN:-0}" \
	FAKE_UNSAFE_CHMOD="${FAKE_UNSAFE_CHMOD:-0}" \
	FAKE_UNSAFE_MV="${FAKE_UNSAFE_MV:-0}" \
	FAKE_UNSAFE_RUNTIME_PARENT="${FAKE_UNSAFE_RUNTIME_PARENT:-0}" \
	FAKE_UNSAFE_RUNTIME_DIR="${FAKE_UNSAFE_RUNTIME_DIR:-0}" \
	FAKE_UNSAFE_HEAVY_LOCK="${FAKE_UNSAFE_HEAVY_LOCK:-0}" \
	FAKE_UNSAFE_PROTECTED_ENV="${FAKE_UNSAFE_PROTECTED_ENV:-0}" \
	FAKE_UNSAFE_PROTECTED_SOURCE="${FAKE_UNSAFE_PROTECTED_SOURCE:-0}" \
	FAKE_SYMLINK_LAUNCHER="${FAKE_SYMLINK_LAUNCHER:-0}" \
	FAKE_SYMLINK_LINUX="${FAKE_SYMLINK_LINUX:-0}" \
	FAKE_SYMLINK_RUNTIME_DIR="${FAKE_SYMLINK_RUNTIME_DIR:-0}" \
	FAKE_SYMLINK_HEAVY_LOCK="${FAKE_SYMLINK_HEAVY_LOCK:-0}" \
	FAKE_SYMLINK_PROTECTED_ENV="${FAKE_SYMLINK_PROTECTED_ENV:-0}" \
	FAKE_SYMLINK_PROTECTED_SOURCE="${FAKE_SYMLINK_PROTECTED_SOURCE:-0}" \
	FAKE_MKDIR_FAIL="${FAKE_MKDIR_FAIL:-0}" \
	FAKE_CHOWN_FAIL="${FAKE_CHOWN_FAIL:-0}" \
	FAKE_CHMOD_FAIL="${FAKE_CHMOD_FAIL:-0}" \
	FAKE_MV_FAIL="${FAKE_MV_FAIL:-0}" \
	FAKE_BOOTSTRAP_FAIL="${FAKE_BOOTSTRAP_FAIL:-0}" \
	FAKE_ATTACH_FAIL="${FAKE_ATTACH_FAIL:-0}" \
	FAKE_PRIVDROP_FAIL="${FAKE_PRIVDROP_FAIL:-0}" \
	FAKE_ROOT_UID="${FAKE_ROOT_UID:-0}" \
	FAKE_ROOT_GID="${FAKE_ROOT_GID:-0}" \
	FAKE_CONTROL_READ_FAIL="${FAKE_CONTROL_READ_FAIL:-0}" \
	FAKE_CONTROL_MISMATCH_PID="${FAKE_CONTROL_MISMATCH_PID:-0}" \
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

project_env="$tmp_dir/project.env"
: >"$log"
: >"$phase_log"
run_script bus-runtime -- "$fake_bin/bus-services" stack up --env-file "$project_env"
cmp "$tmp_dir/expected-bootstrap" "$bootstrap_args"
cat >"$tmp_dir/expected-command-args" <<EOF
stack
up
--env-file
$project_env
--env-file
$protected_env_path
EOF
cmp "$tmp_dir/expected-command-args" "$command_args"
cmp "$control_file" "$command_pid"
[ "$(wc -l <"$control_file")" -eq 1 ]
printf '%s\n' "$protected_env_path" >"$tmp_dir/expected-command-env-file"
cmp "$tmp_dir/expected-command-env-file" "$command_env_file"
sed "s|^BUS_SERVICES_LINUX_INTEGRATION_BIN=.*$|BUS_SERVICES_LINUX_INTEGRATION_BIN=$fake_bin/bus-integration-linux|" "$config" >"$tmp_dir/expected-command-env"
cmp "$tmp_dir/expected-command-env" "$protected_env_path"
cmp "$tmp_dir/expected-command-env" "$command_env"
cat >"$tmp_dir/expected-phases" <<'EOF'
create-runtime-parent
chown-runtime-parent-root
chmod-runtime-parent-root
chown-heavy-lock
chmod-heavy-lock
chown-protected-env
chmod-protected-env
publish-protected-env
bootstrap
privdrop
stack-command
EOF
cmp "$tmp_dir/expected-phases" "$phase_log"
test "$(grep -xc 'bootstrap' "$log")" -eq 1
grep -Fq 'fixed-id <-u>' "$log"
grep -Fq "fixed-stat <%F> <$fake_bin/bus-services-protected-run>" "$log"
grep -Fq "fixed-readlink <$fake_bin/bus-services-protected-run>" "$log"
grep -Fq "fixed-chown <0:0> <--> <$runtime_dir>" "$log"
grep -Fq "fixed-chmod <0755> <--> <$runtime_dir>" "$log"
grep -Fq "fixed-chown <1004:1005> <--> <$heavy_lock_path>" "$log"
grep -Fq "fixed-chmod <0600> <--> <$heavy_lock_path>" "$log"
grep -Eq "fixed-chown <1004:1005> <--> <$runtime_dir/\.services-protected\.env\.[0-9]+>" "$log"
grep -Eq "fixed-chmod <0600> <--> <$runtime_dir/\.services-protected\.env\.[0-9]+>" "$log"
grep -Fq 'privdrop <--user> <bus-runtime> <--> </bin/sh> <-ceu>' "$log"
[ "$(stat -c %a "$heavy_lock_path")" = 600 ]
[ "$(stat -c %a "$protected_env_path")" = 600 ]
! grep -q 'path-injection\|work-exec\|unexpected-integration' "$log"

: >"$log"
: >"$phase_log"
rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_env_file" "$command_pid"
run_script bus-runtime -- "$fake_bin/exec-target" 'value with spaces' --leading-dash
cmp "$tmp_dir/expected-bootstrap" "$bootstrap_args"
cat >"$tmp_dir/expected-arbitrary-args" <<'EOF'
value with spaces
--leading-dash
EOF
cmp "$tmp_dir/expected-arbitrary-args" "$command_args"
[ ! -e "$command_env" ]
[ ! -e "$command_env_file" ]
cmp "$control_file" "$command_pid"
cat >"$tmp_dir/expected-arbitrary-phases" <<'EOF'
bootstrap
privdrop
arbitrary-command
EOF
cmp "$tmp_dir/expected-arbitrary-phases" "$phase_log"
test "$(grep -xc 'bootstrap' "$log")" -eq 1

expect_stack_env_injection() {
	: >"$log"
	: >"$phase_log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_env_file" "$command_pid"
	run_script bus-runtime -- "$@"
	tail -n 2 "$command_args" >"$tmp_dir/actual-env-tail"
	cat >"$tmp_dir/expected-env-tail" <<EOF
--env-file
$protected_env_path
EOF
	cmp "$tmp_dir/expected-env-tail" "$tmp_dir/actual-env-tail"
	cmp "$tmp_dir/expected-command-env-file" "$command_env_file"
	cmp "$tmp_dir/expected-command-env" "$command_env"
	cmp "$control_file" "$command_pid"
	test "$(grep -xc 'bootstrap' "$log")" -eq 1
	test "$(grep -xc 'stack-command' "$phase_log")" -eq 1
}

expect_stack_env_injection "$fake_bin/bus-services" up
expect_stack_env_injection "$fake_bin/bus-services" restart example-service
expect_stack_env_injection "$fake_bin/bus-integration-services" stack up
expect_stack_env_injection "$fake_bin/bus-integration-services" serve

grep -qx 'BUS_SERVICES_PROTECTED=1' <(sed -n '1p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_MOUNT=/sys/fs/cgroup' <(sed -n '2p' "$config")
grep -qx 'BUS_SERVICES_CGROUP_IDENTITY=bus-services' <(sed -n '3p' "$config")
grep -qx 'BUS_SERVICES_LINUX_INTEGRATION_BIN=/usr/local/bin/bus-integration-linux' <(sed -n '4p' "$config")
test "$(wc -l <"$config")" -eq 4
git show d109f1b:services.yml >"$tmp_dir/expected-services.yml"
cmp "$tmp_dir/expected-services.yml" "$services"

make -C "$root_dir" -n install MODULE_DIRS= DESTDIR="$tmp_dir/install-root" BINDIR=/usr/local/bin >"$tmp_dir/install-dry-run"
grep -Fq 'scripts/bus-services-protected-run' "$tmp_dir/install-dry-run"
grep -Fq 'config/services-protected.env' "$tmp_dir/install-dry-run"
make -C "$root_dir" install MODULE_DIRS= DESTDIR="$tmp_dir/install-root" BINDIR=/usr/local/bin
installed_launcher="$tmp_dir/install-root/usr/local/bin/bus-services-protected-run"
installed_config="$tmp_dir/install-root/usr/local/bin/bus-services-protected.env"
[ -f "$installed_launcher" ]
[ "$(stat -c %a "$installed_launcher")" = 755 ]
[ -f "$installed_config" ]
[ "$(stat -c %a "$installed_config")" = 644 ]
cmp "$config" "$installed_config"

installed_dir=${installed_launcher%/*}
/usr/bin/cp "$fake_bin/bus-integration-linux" "$installed_dir/bus-integration-linux"
/usr/bin/cp "$fake_bin/stack-target" "$installed_dir/bus-services"
write_test_launcher "$installed_launcher" "$tmp_dir/installed-launcher-under-test"
/usr/bin/mv "$tmp_dir/installed-launcher-under-test" "$installed_launcher"
launcher_under_test=$installed_launcher
non_repo_cwd="$tmp_dir/non-repo-cwd"
mkdir -p "$non_repo_cwd"
: >"$log"
: >"$phase_log"
rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_env_file" "$command_pid"
(
	cd "$non_repo_cwd"
	run_script bus-runtime -- "$installed_dir/bus-services" up
)
sed "s|^BUS_SERVICES_LINUX_INTEGRATION_BIN=.*$|BUS_SERVICES_LINUX_INTEGRATION_BIN=$installed_dir/bus-integration-linux|" "$installed_config" >"$tmp_dir/expected-installed-env"
cmp "$tmp_dir/expected-installed-env" "$protected_env_path"
cmp "$tmp_dir/expected-installed-env" "$command_env"
printf '%s\n' "$protected_env_path" >"$tmp_dir/expected-installed-env-file"
cmp "$tmp_dir/expected-installed-env-file" "$command_env_file"
cmp "$control_file" "$command_pid"
test "$(grep -xc 'bootstrap' "$log")" -eq 1
launcher_under_test=$test_script

assert_command_not_run() {
	[ ! -s "$command_args" ]
	[ ! -s "$command_env" ]
	[ ! -s "$command_env_file" ]
	[ ! -s "$command_pid" ]
}

expect_failure_without_bootstrap() {
	setting=$1
	shift
	if [ -n "$setting" ]; then export "$setting"; fi
	: >"$log"
	: >"$phase_log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_env_file" "$command_pid"
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
	: >"$phase_log"
	rm -f "$bootstrap_args" "$command_args" "$command_env" "$command_env_file" "$command_pid"
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
expect_failure_without_bootstrap FAKE_UNSAFE_MKDIR=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_CHOWN=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_CHMOD=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_MV=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_ROOT_UID=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_ROOT_GID=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_PARENT=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_PARENT=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_PARENT=3 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_DIR=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_DIR=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_DIR=3 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_RUNTIME_DIR=4 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_SYMLINK_RUNTIME_DIR=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_HEAVY_LOCK=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_HEAVY_LOCK=2 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_HEAVY_LOCK=3 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_HEAVY_LOCK=4 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_SYMLINK_HEAVY_LOCK=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_ENV=1 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_ENV=2 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_ENV=3 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_ENV=4 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_SYMLINK_PROTECTED_ENV=1 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_SOURCE=1 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_SOURCE=2 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_SOURCE=3 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_UNSAFE_PROTECTED_SOURCE=4 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_without_bootstrap FAKE_SYMLINK_PROTECTED_SOURCE=1 bus-runtime -- "$fake_bin/bus-services" up
expect_failure_after_bootstrap FAKE_BOOTSTRAP_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_ATTACH_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_PRIVDROP_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_CONTROL_READ_FAIL=1 bus-runtime -- "$fake_bin/exec-target"
expect_failure_after_bootstrap FAKE_CONTROL_MISMATCH_PID=1 bus-runtime -- "$fake_bin/exec-target"

! grep -Eq '(^|[[:space:]])(systemctl|systemd-run|sudo)([[:space:]]|$)' "$source_script"
! grep -q 'cgroup work-exec' "$source_script"

printf 'protected Services install/config regression OK\n'
