#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-rebase-abort-test.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

mkdir "$tmp_dir/sub-src"
git_config -C "$tmp_dir/sub-src" init -b develop >/dev/null
printf 'module base\n' >"$tmp_dir/sub-src/module.txt"
git_config -C "$tmp_dir/sub-src" add module.txt
git_config -C "$tmp_dir/sub-src" commit -m 'submodule base' >/dev/null
sub_base="$(git -C "$tmp_dir/sub-src" rev-parse HEAD)"
printf 'module local\n' >"$tmp_dir/sub-src/module.txt"
git_config -C "$tmp_dir/sub-src" add module.txt
git_config -C "$tmp_dir/sub-src" commit -m 'submodule local head' >/dev/null
sub_local="$(git -C "$tmp_dir/sub-src" rev-parse HEAD)"

mkdir "$tmp_dir/root-src"
git_config -C "$tmp_dir/root-src" init -b develop >/dev/null
mkdir "$tmp_dir/root-src/scripts"
cp "$root_dir/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules.sh"
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-src" module-a
git_config -C "$tmp_dir/root-src/module-a" checkout --quiet "$sub_base"
printf 'base\n' >"$tmp_dir/root-src/conflict.txt"
git_config -C "$tmp_dir/root-src" add .gitmodules conflict.txt module-a scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null

git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"
git_config -C "$tmp_dir/root-src" remote add origin "$tmp_dir/root-origin.git"
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-checkout"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-checkout" submodule update --init module-a >/dev/null
git_config -C "$tmp_dir/root-checkout/module-a" checkout --quiet -B develop "$sub_local"
git_config -C "$tmp_dir/root-checkout/module-a" branch --set-upstream-to=origin/develop develop >/dev/null
git_config -C "$tmp_dir/root-checkout" add module-a
git_config -C "$tmp_dir/root-checkout" commit -m 'root pins local submodule head' >/dev/null
printf 'local\n' >"$tmp_dir/root-checkout/conflict.txt"
git_config -C "$tmp_dir/root-checkout" add conflict.txt
git_config -C "$tmp_dir/root-checkout" commit -m 'root local content' >/dev/null
local_root_head="$(git -C "$tmp_dir/root-checkout" rev-parse HEAD)"

printf 'module remote\n' >"$tmp_dir/sub-src/module.txt"
git_config -C "$tmp_dir/sub-src" add module.txt
git_config -C "$tmp_dir/sub-src" commit -m 'submodule remote head' >/dev/null
sub_remote="$(git -C "$tmp_dir/sub-src" rev-parse HEAD)"
git_config -C "$tmp_dir/root-src/module-a" fetch --quiet origin "$sub_remote"
git_config -C "$tmp_dir/root-src/module-a" checkout --quiet "$sub_remote"
git_config -C "$tmp_dir/root-src" add module-a
git_config -C "$tmp_dir/root-src" commit -m 'root pins remote submodule head' >/dev/null
printf 'remote\n' >"$tmp_dir/root-src/conflict.txt"
git_config -C "$tmp_dir/root-src" add conflict.txt
git_config -C "$tmp_dir/root-src" commit -m 'root remote content' >/dev/null
git_config -C "$tmp_dir/root-src" push --quiet origin develop

sync_out="$tmp_dir/sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-checkout/scripts/sync-submodules.sh" --pull-only --jobs 1 --verbose . >"$sync_out" 2>&1; then
	cat "$sync_out" >&2
	printf 'FAIL sync-submodules fixture: conflicting rebase unexpectedly succeeded\n' >&2
	exit 1
fi

test "$(git -C "$tmp_dir/root-checkout" rev-parse HEAD)" = "$local_root_head"
test "$(git -C "$tmp_dir/root-checkout/module-a" rev-parse HEAD)" = "$sub_local"
test "$(git -C "$tmp_dir/root-checkout/module-a" branch --show-current)" = "develop"
test -z "$(git -C "$tmp_dir/root-checkout" status --porcelain)"
test ! -d "$(git -C "$tmp_dir/root-checkout" rev-parse --git-dir)/rebase-merge"
test "$sub_remote" != "$sub_local"

printf 'sync submodules rebase abort restores submodules OK\n'
