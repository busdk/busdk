#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-push-fetch-retry-test.$$"
if [ "${KEEP_THREAD200_FIXTURE:-0}" = 1 ]; then
	trap 'printf "sync submodules push-fetch retry fixture retained at %s\\n" "$tmp_dir"' EXIT
else
	trap 'rm -rf "$tmp_dir"' EXIT
fi

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

make_checkout() {
	local name="$1"
	local origin="$2"
	local checkout="$tmp_dir/$name"
	local hook

	GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/$origin" "$checkout"
	GIT_ALLOW_PROTOCOL=file git_config -C "$checkout" submodule update --init --quiet
	git_config -C "$checkout/module-a" checkout --quiet develop

	printf 'same logical change\n' >"$checkout/README.md"
	git_config -C "$checkout" add README.md
	git_config -C "$checkout" commit -m 'local duplicate parent change' >/dev/null

	GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/$origin" "$tmp_dir/$name-peer"
	printf 'same logical change\n' >"$tmp_dir/$name-peer/README.md"
	git_config -C "$tmp_dir/$name-peer" add README.md
	git_config -C "$tmp_dir/$name-peer" commit -m 'remote duplicate parent change' >/dev/null

	hook="$checkout/.git/hooks/pre-push"
	printf '#!/bin/sh\ngit -C "%s/%s-peer" push --quiet origin develop\n' "$tmp_dir" "$name" >"$hook"
	chmod +x "$hook"
}

mkdir "$tmp_dir/sub-work"
git_config -C "$tmp_dir/sub-work" init -b develop >/dev/null
printf 'module base\n' >"$tmp_dir/sub-work/module.txt"
git_config -C "$tmp_dir/sub-work" add module.txt
git_config -C "$tmp_dir/sub-work" commit -m 'submodule base' >/dev/null
git_config -C "$tmp_dir/sub-work" clone --quiet --bare . "$tmp_dir/sub-origin.git"

mkdir "$tmp_dir/root-src"
git_config -C "$tmp_dir/root-src" init -b develop >/dev/null
mkdir "$tmp_dir/root-src/scripts"
cp "$root_dir/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules.sh"
sed 's/sync_push "$dir" "$upstream"/run_git_step "$dir" push push/' \
	"$root_dir/scripts/sync-submodules.sh" >"$tmp_dir/root-src/scripts/sync-submodules-baseline.sh"
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules-baseline.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-origin.git" module-a
printf 'root base\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a scripts
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null
git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-candidate-origin.git"
cp "$tmp_dir/root-src/scripts/sync-submodules-baseline.sh" "$tmp_dir/root-src/scripts/sync-submodules.sh"
git_config -C "$tmp_dir/root-src" add scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit --amend --no-edit >/dev/null
git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-baseline-origin.git"

make_checkout root-baseline root-baseline-origin.git
baseline_out="$tmp_dir/baseline-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-baseline/scripts/sync-submodules.sh" --jobs 1 --verbose >"$baseline_out" 2>&1; then
	cat "$baseline_out" >&2
	exit 1
fi
grep -Fq 'warning: push failed for .: git push' "$baseline_out"
grep -Fq 'sync-submodules: ok=1 skipped=0 failed=1 total=2' "$baseline_out"

make_checkout root-candidate root-candidate-origin.git
candidate_out="$tmp_dir/candidate-sync.out"
GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-candidate/scripts/sync-submodules.sh" --jobs 1 --verbose >"$candidate_out" 2>&1
grep -Fq 'warning: push failed for .: git push' "$candidate_out"
grep -Fq 'retrying push for . after fetching origin/develop' "$candidate_out"
grep -Fq 'sync-submodules: ok=2 skipped=0 failed=0 total=2' "$candidate_out"
test -z "$(git -C "$tmp_dir/root-candidate" status --porcelain)"
test "$(git -C "$tmp_dir/root-candidate" rev-parse HEAD)" = "$(git -C "$tmp_dir/root-candidate-origin.git" rev-parse develop)"
test "$(git -C "$tmp_dir/root-candidate" log --format=%s -1)" = 'remote duplicate parent change'

printf 'sync submodules push fetch retry OK\n'
