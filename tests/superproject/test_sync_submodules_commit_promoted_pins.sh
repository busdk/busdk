#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-commit-promoted-pins-test.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
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
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-origin.git" module-a
printf 'root\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null
git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"

GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-checkout"

printf 'module updated\n' >"$tmp_dir/sub-work/module.txt"
git_config -C "$tmp_dir/sub-work" add module.txt
git_config -C "$tmp_dir/sub-work" commit -m 'submodule update' >/dev/null
sub_head="$(git -C "$tmp_dir/sub-work" rev-parse HEAD)"
git_config -C "$tmp_dir/sub-work" push --quiet "$tmp_dir/sub-origin.git" develop

sync_out="$tmp_dir/sync.out"
if ! GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-checkout/scripts/sync-submodules.sh" --jobs 1 --verbose >"$sync_out"; then
	cat "$sync_out" >&2
	exit 1
fi

grep -Fq 'sync-submodules: staged 1 submodule pin(s); commit the superproject to record them.' "$sync_out"
grep -Fq 'sync-submodules: ok=2 skipped=0 failed=0 total=2' "$sync_out"
if grep -Fq 'warning: skipping .: working tree has uncommitted changes' "$sync_out"; then
	cat "$sync_out" >&2
	exit 1
fi

test "$(git -C "$tmp_dir/root-checkout/module-a" rev-parse HEAD)" = "$sub_head"
test "$(git -C "$tmp_dir/root-checkout" rev-parse HEAD:module-a)" = "$sub_head"
test -z "$(git -C "$tmp_dir/root-checkout" status --porcelain)"

git_config -C "$tmp_dir/root-origin.git" fetch --quiet "$tmp_dir/root-checkout" develop:develop
test "$(git -C "$tmp_dir/root-origin.git" rev-parse develop:module-a)" = "$sub_head"

printf 'sync submodules commit promoted pins OK\n'
