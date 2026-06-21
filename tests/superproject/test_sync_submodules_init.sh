#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-init-test.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

mkdir "$tmp_dir/sub-src"
git_config -C "$tmp_dir/sub-src" init -b develop >/dev/null
printf 'module\n' >"$tmp_dir/sub-src/module.txt"
git_config -C "$tmp_dir/sub-src" add module.txt
git_config -C "$tmp_dir/sub-src" commit -m 'submodule base' >/dev/null
sub_head="$(git -C "$tmp_dir/sub-src" rev-parse HEAD)"

mkdir "$tmp_dir/root-src"
git_config -C "$tmp_dir/root-src" init -b develop >/dev/null
mkdir "$tmp_dir/root-src/scripts"
cp "$root_dir/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules.sh"
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-src" module-a
printf 'root\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null

git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-checkout"

test "$(git -C "$tmp_dir/root-checkout" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout"
if [ "$(git -C "$tmp_dir/root-checkout/module-a" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout/module-a" ]; then
	printf 'FAIL sync-submodules init: module-a unexpectedly initialized before sync\n' >&2
	exit 1
fi

sync_out="$tmp_dir/sync.out"
GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-checkout/scripts/sync-submodules.sh" --pull-only --jobs 1 --verbose module-a >"$sync_out"
grep -Fq 'sync-submodules: ok=1 skipped=0 failed=0 total=1' "$sync_out"

test "$(git -C "$tmp_dir/root-checkout/module-a" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout/module-a"
test "$(git -C "$tmp_dir/root-checkout/module-a" rev-parse HEAD)" = "$sub_head"
test "$(git -C "$tmp_dir/root-checkout/module-a" branch --show-current)" = "develop"
test -z "$(git -C "$tmp_dir/root-checkout" status --porcelain)"

printf 'sync submodules init OK\n'
