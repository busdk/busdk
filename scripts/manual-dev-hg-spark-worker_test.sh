#!/bin/sh
set -eu

# Focused test for T170's ephemeral-tmp routing slice: manual/direct worker
# launches must never resolve TMPDIR/TMP/TEMP/GOTMPDIR to system tmp, and
# `stop` must remove only the exact worker's own ephemeral-tmp child.

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
script="$repo_root/scripts/manual-dev-hg-spark-worker.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/manual-dev-hg-spark-worker-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
	printf 'manual-dev-hg-spark-worker test: %s\n' "$*" >&2
	exit 1
}

expect_contains() {
	file=$1
	needle=$2
	grep -F -- "$needle" "$file" >/dev/null || fail "missing in $file: $needle"
}

init_repo() {
	path=$1
	branch=$2
	git init -q -b "$branch" "$path"
	git -C "$path" config user.email spark-test@example.invalid
	git -C "$path" config user.name 'Spark Test'
	printf '%s\n' "$branch" >"$path/README.md"
	git -C "$path" add README.md
	git -C "$path" commit -q -m initial
}

product_repo="$tmp/product"
identity_repo="$tmp/identity"
init_repo "$product_repo" main
init_repo "$identity_repo" main

fake_bin="$tmp/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/codex" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fake_bin/codex"

# Stub screen: this test only needs to inspect the generated runner script and
# meta.env content plus directory side effects, all of which happen before
# `start` invokes screen. A real screen session is unnecessary and, in a
# non-interactive/no-tty sandbox, can hang waiting on a pty; stubbing it keeps
# this test fast and deterministic. `-ls` prints nothing (so
# screen_session_alive always reports not-alive, taking stop's safe fallback
# branch); every other invocation (-dmS, -X quit) is a no-op success.
cat >"$fake_bin/screen" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fake_bin/screen"

worker_root="$tmp/workers"
# This host's real $HOME/.codex is the live, multi-gigabyte, socket-bearing
# state of an actual running agent session, not a small credentials
# directory. Point auth-home seeding at an empty directory instead, so the
# unrelated real auth home is never statted, copied, or blocked on here.
empty_auth_home="$tmp/empty-auth-home"
mkdir -p "$empty_auth_home"

run_launcher() {
	BUS_MANUAL_SPARK_REPO="$product_repo" \
	BUS_MANUAL_SPARK_WORKER_ROOT="$worker_root" \
	BUS_MANUAL_SPARK_WORKER_REPO="$identity_repo" \
	BUS_MANUAL_SPARK_MODEL='fake-model' \
	BUS_MANUAL_SPARK_CODEX="$fake_bin/codex" \
	BUS_MANUAL_SPARK_AUTH_HOME="$empty_auth_home" \
	BUS_MANUAL_SPARK_BASE_REF=main \
	BUS_MANUAL_SPARK_WORKER_BASE_REF=main \
	PATH="$fake_bin:$PATH" \
	sh "$script" "$@"
}

prompt_file="$tmp/prompt.md"
printf 'focused ephemeral-tmp test prompt\n' >"$prompt_file"

run_launcher start worker-a . codex/worker-a "$prompt_file" >"$tmp/start-a.out" 2>"$tmp/start-a.err" \
	|| { cat "$tmp/start-a.out" "$tmp/start-a.err" >&2; fail 'start worker-a failed'; }
run_launcher start worker-b . codex/worker-b "$prompt_file" >"$tmp/start-b.out" 2>"$tmp/start-b.err" \
	|| { cat "$tmp/start-b.out" "$tmp/start-b.err" >&2; fail 'start worker-b failed'; }

runner_a="$worker_root/worker-a/run-codex.sh"
meta_a="$worker_root/worker-a/meta.env"
ephemeral_a="$worker_root/worker-a/ephemeral-tmp"
ephemeral_b="$worker_root/worker-b/ephemeral-tmp"

[ -f "$runner_a" ] || fail "runner script missing: $runner_a"
expect_contains "$runner_a" "export TMPDIR='$ephemeral_a'"
expect_contains "$runner_a" "export TMP='$ephemeral_a'"
expect_contains "$runner_a" "export TEMP='$ephemeral_a'"
expect_contains "$runner_a" "export GOTMPDIR='$ephemeral_a'"

if grep -F -- "TMPDIR='/tmp'" "$runner_a" >/dev/null; then
	fail 'runner routes TMPDIR to system /tmp'
fi

[ -d "$ephemeral_a" ] || fail "ephemeral tmp dir was not created: $ephemeral_a"
[ -d "$ephemeral_b" ] || fail "sibling ephemeral tmp dir was not created: $ephemeral_b"
expect_contains "$meta_a" "ephemeral_tmp_path=$ephemeral_a"

run_launcher stop worker-a >"$tmp/stop-a.out" 2>"$tmp/stop-a.err" \
	|| { cat "$tmp/stop-a.out" "$tmp/stop-a.err" >&2; fail 'stop worker-a failed'; }

if [ -d "$ephemeral_a" ]; then
	fail "worker-a ephemeral tmp still exists after stop: $ephemeral_a"
fi
if [ ! -d "$ephemeral_b" ]; then
	fail "stopping worker-a removed worker-b's ephemeral tmp"
fi

printf 'manual-dev-hg-spark-worker ephemeral-tmp routing: PASS\n'
