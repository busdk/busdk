#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/ssh" <<'SH'
#!/usr/bin/env sh
set -eu
last=
for arg in "$@"; do
	last=$arg
done
printf '%s\n' "$last" >"$H100_SSH_REMOTE_SCRIPT_LOG"
printf 'preflight ok: root=/remote image=worker model=model events=http://127.0.0.1:8081 token_refreshed=true token_file=/home/dev/.config/bus/auth/api-token\n'
SH
chmod +x "$tmp_dir/bin/ssh"

runner_out="$tmp_dir/h100.out"
runner_err="$tmp_dir/h100.err"
PATH="$tmp_dir/bin:$PATH" H100_SSH_REMOTE_SCRIPT_LOG="$tmp_dir/h100.remote-script" \
	"$root_dir/scripts/h100-offload-runner.sh" \
	--mode preflight \
	--ssh-target dev@ai.hg.fi \
	--remote-root /remote \
	--model model \
	--image worker \
	--events-url http://127.0.0.1:8081 \
	--timeout 7 \
	--ensure-services \
	--refresh-token \
	--remote-token-file /home/dev/.config/bus/auth/api-token >"$runner_out" 2>"$runner_err"

grep -Fq 'token_refreshed=true' "$runner_out"
grep -Fq 'bus-events' "$tmp_dir/h100.remote-script"
grep -Fq 'bus-integration-docker' "$tmp_dir/h100.remote-script"
grep -Fq 'bus-integration-containers' "$tmp_dir/h100.remote-script"
grep -Fq 'bus-operator-token --format token issue --local' "$tmp_dir/h100.remote-script"
grep -Fq -- '--scope "$token_scope"' "$tmp_dir/h100.remote-script"
grep -Fq 'chmod 600 "$tmp_token"' "$tmp_dir/h100.remote-script"
grep -Fq 'mv "$tmp_token" "$token_file"' "$tmp_dir/h100.remote-script"
if grep -Fq 'not-a-secret-local-development-hs256-key' "$runner_out" "$runner_err"; then
	printf 'FAIL h100 runner printed signing material\n' >&2
	exit 1
fi

cat >"$tmp_dir/bin/ssh" <<'SH'
#!/usr/bin/env sh
sleep 3
SH
chmod +x "$tmp_dir/bin/ssh"
timeout_out="$tmp_dir/h100-timeout.out"
timeout_err="$tmp_dir/h100-timeout.err"
if PATH="$tmp_dir/bin:$PATH" "$root_dir/scripts/h100-offload-runner.sh" \
	--mode preflight \
	--ssh-target dev@ai.hg.fi \
	--remote-root /remote \
	--model model \
	--image worker \
	--events-url http://127.0.0.1:8081 \
	--timeout 1 >"$timeout_out" 2>"$timeout_err"; then
	printf 'FAIL h100 runner timeout preflight unexpectedly passed\n' >&2
	exit 1
fi
grep -Fq 'timed out after 1 seconds waiting for ssh target dev@ai.hg.fi' "$timeout_err"
grep -Fq 'preflight failed target=dev@ai.hg.fi root=/remote timeout=1 status=124' "$timeout_err"

cat >"$tmp_dir/local-bus-events" <<'SH'
#!/usr/bin/env sh
set -eu
out=
mode=
while [ "$#" -gt 0 ]; do
	case "$1" in
		-o) out=$2; shift 2 ;;
		export|import) mode=$1; shift ;;
		*) shift ;;
	esac
done
case "$mode" in
	export)
		printf '{"name":"bus.dev.task.new"}\n' >"$out"
		;;
	import)
		;;
	*)
		printf 'unexpected bus-events mode\n' >&2
		exit 1
		;;
esac
SH
chmod +x "$tmp_dir/local-bus-events"

cat >"$tmp_dir/h100-runner" <<'SH'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" >"$H100_RUNNER_ARGS_LOG"
printf 'preflight ok: token_refreshed=true\n'
SH
chmod +x "$tmp_dir/h100-runner"

cat >"$tmp_dir/bin/ssh" <<'SH'
#!/usr/bin/env sh
set -eu
cmd=
for arg in "$@"; do
	cmd=$arg
done
all=$*
case "$all" in
	*" sh -s"*)
		cat >/dev/null
		;;
	*"cat > "*)
		cat >/dev/null
		;;
	*cat*)
		printf '{"name":"bus.dev.task.done"}\n'
		;;
	*)
		printf 'unexpected ssh command: %s\n' "$cmd" >&2
		exit 1
		;;
esac
SH
chmod +x "$tmp_dir/bin/ssh"

printf 'local-token-value\n' >"$tmp_dir/local-token"
sync_out="$tmp_dir/sync.out"
sync_err="$tmp_dir/sync.err"
PATH="$tmp_dir/bin:$PATH" H100_RUNNER_ARGS_LOG="$tmp_dir/h100-runner.args" \
	"$root_dir/scripts/sync-events-over-ssh.sh" \
	--ssh-target dev@ai.hg.fi \
	--remote-root /home/dev/workspace/busdk/busdk \
	--local-api-url http://127.0.0.1:8081 \
	--remote-api-url http://127.0.0.1:8081 \
	--local-token-file "$tmp_dir/local-token" \
	--remote-token-file /home/dev/.config/bus/auth/api-token \
	--local-events-bin "$tmp_dir/local-bus-events" \
	--h100-runner "$tmp_dir/h100-runner" \
	--remote-tmp /tmp/bus-events-ssh-sync-test.ndjson \
	--name bus.dev.task.done \
	--direction both \
	--repeat 1 \
	--ssh-wait-timeout 7 \
	--ensure-h100-readiness \
	--h100-readiness-timeout 13 >"$sync_out" 2>"$sync_err"

grep -Fq -- '--ensure-services' "$tmp_dir/h100-runner.args"
grep -Fq -- '--refresh-token' "$tmp_dir/h100-runner.args"
grep -Fq -- '--timeout 13' "$tmp_dir/h100-runner.args"
grep -Fq -- '--remote-token-file /home/dev/.config/bus/auth/api-token' "$tmp_dir/h100-runner.args"
grep -Fq -- '--services bus-events bus-integration-docker bus-integration-containers' "$tmp_dir/h100-runner.args"
grep -Fq 'h100-readiness ok: target=dev@ai.hg.fi timeout=13' "$sync_err"
grep -Fq 'local-to-remote events=1' "$sync_out"
grep -Fq 'remote-to-local events=1' "$sync_out"
if grep -Fq 'local-token-value' "$sync_out" "$sync_err"; then
	printf 'FAIL sync helper printed token file contents\n' >&2
	exit 1
fi

cat >"$tmp_dir/h100-runner" <<'SH'
#!/usr/bin/env sh
set -eu
printf 'h100 runner should not have been called\n' >&2
exit 91
SH
chmod +x "$tmp_dir/h100-runner"
skip_out="$tmp_dir/sync-skip.out"
skip_err="$tmp_dir/sync-skip.err"
PATH="$tmp_dir/bin:$PATH" "$root_dir/scripts/sync-events-over-ssh.sh" \
	--ssh-target dev@ai.hg.fi \
	--remote-root /home/dev/workspace/busdk/busdk \
	--local-api-url http://127.0.0.1:8081 \
	--remote-api-url http://127.0.0.1:8081 \
	--local-token-file "$tmp_dir/local-token" \
	--remote-token-file /home/dev/.config/bus/auth/api-token \
	--local-events-bin "$tmp_dir/local-bus-events" \
	--h100-runner "$tmp_dir/h100-runner" \
	--remote-tmp /tmp/bus-events-ssh-sync-test.ndjson \
	--name bus.dev.task.done \
	--direction both \
	--repeat 1 \
	--ssh-wait-timeout 7 >"$skip_out" 2>"$skip_err"
grep -Fq 'h100-readiness skipped: target=dev@ai.hg.fi mode=false' "$skip_err"
grep -Fq 'local-to-remote events=1' "$skip_out"
grep -Fq 'remote-to-local events=1' "$skip_out"

cat >"$tmp_dir/h100-runner" <<'SH'
#!/usr/bin/env sh
set -eu
printf 'runner failed clearly\n' >&2
exit 42
SH
chmod +x "$tmp_dir/h100-runner"
fail_out="$tmp_dir/sync-fail.out"
fail_err="$tmp_dir/sync-fail.err"
if PATH="$tmp_dir/bin:$PATH" "$root_dir/scripts/sync-events-over-ssh.sh" \
	--ssh-target dev@ai.hg.fi \
	--remote-root /home/dev/workspace/busdk/busdk \
	--local-api-url http://127.0.0.1:8081 \
	--remote-api-url http://127.0.0.1:8081 \
	--local-token-file "$tmp_dir/local-token" \
	--remote-token-file /home/dev/.config/bus/auth/api-token \
	--local-events-bin "$tmp_dir/local-bus-events" \
	--h100-runner "$tmp_dir/h100-runner" \
	--remote-tmp /tmp/bus-events-ssh-sync-test.ndjson \
	--name bus.dev.task.done \
	--direction both \
	--repeat 1 \
	--ssh-wait-timeout 7 \
	--ensure-h100-readiness \
	--h100-readiness-timeout 5 >"$fail_out" 2>"$fail_err"; then
	printf 'FAIL sync readiness failure unexpectedly passed\n' >&2
	exit 1
fi
grep -Fq 'h100-readiness failed: target=dev@ai.hg.fi' "$fail_err"
grep -Fq 'timeout=5 status=42' "$fail_err"
grep -Fq 'h100-readiness: runner failed clearly' "$fail_err"
grep -Fq 'use --no-ensure-h100-readiness when services are already running' "$fail_err"

printf 'h100 readiness scripts OK\n'
