#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/remote-checkout-update-test.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

mkdir "$tmp_dir/sub-src"
git_config -C "$tmp_dir/sub-src" init -b main >/dev/null
printf 'one\n' >"$tmp_dir/sub-src/value.txt"
git_config -C "$tmp_dir/sub-src" add value.txt
git_config -C "$tmp_dir/sub-src" commit -m 'sub one' >/dev/null
sub_pin=$(git -C "$tmp_dir/sub-src" rev-parse HEAD)

mkdir "$tmp_dir/root-src"
git_config -C "$tmp_dir/root-src" init -b main >/dev/null
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b main "$tmp_dir/sub-src" module-a
printf 'root one\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a
git_config -C "$tmp_dir/root-src" commit -m 'root one' >/dev/null
root_initial=$(git -C "$tmp_dir/root-src" rev-parse HEAD)

git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/remote-checkout"
test "$(git -C "$tmp_dir/remote-checkout" rev-parse HEAD)" = "$root_initial"

printf 'two\n' >"$tmp_dir/sub-src/value.txt"
git_config -C "$tmp_dir/sub-src" commit -am 'sub two' >/dev/null
sub_branch_head=$(git -C "$tmp_dir/sub-src" rev-parse HEAD)

printf 'root two\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" commit -am 'root two' >/dev/null
root_updated=$(git -C "$tmp_dir/root-src" rev-parse HEAD)
git_config -C "$tmp_dir/root-src" push --quiet "$tmp_dir/root-origin.git" main

status_out="$tmp_dir/status.out"
"$root_dir/scripts/remote-checkout-update.sh" \
	--root "$tmp_dir/remote-checkout" \
	--status \
	--submodule module-a >"$status_out"
grep -Fq "root commit=$root_initial branch=main" "$status_out"
grep -Fq "submodule path=module-a pin=$sub_pin head=uninitialized" "$status_out"

dry_run_out="$tmp_dir/dry-run.out"
"$root_dir/scripts/remote-checkout-update.sh" \
	--root "$tmp_dir/remote-checkout" \
	--dry-run \
	--branch main \
	--submodule module-a >"$dry_run_out"
grep -Fq "+ 'git' '-C' '$tmp_dir/remote-checkout' 'fetch' '--quiet' 'origin' 'main'" "$dry_run_out"
grep -Fq "root commit=$root_initial branch=main" "$dry_run_out"
grep -Fq "submodule path=module-a pin=$sub_pin head=uninitialized" "$dry_run_out"
test "$(git -C "$tmp_dir/remote-checkout" rev-parse HEAD)" = "$root_initial"
! git -C "$tmp_dir/remote-checkout/module-a" rev-parse HEAD >/dev/null 2>&1

pins_out="$tmp_dir/pins.out"
GIT_ALLOW_PROTOCOL=file "$root_dir/scripts/remote-checkout-update.sh" \
	--root "$tmp_dir/remote-checkout" \
	--branch main \
	--submodule module-a >"$pins_out"
grep -Fq "root commit=$root_updated branch=main" "$pins_out"
grep -Fq "submodule path=module-a pin=$sub_pin head=$sub_pin" "$pins_out"
test "$(git -C "$tmp_dir/remote-checkout/module-a" rev-parse HEAD)" = "$sub_pin"

remote_out="$tmp_dir/remote.out"
GIT_ALLOW_PROTOCOL=file "$root_dir/scripts/remote-checkout-update.sh" \
	--root "$tmp_dir/remote-checkout" \
	--branch main \
	--submodule-mode remote \
	--submodule module-a >"$remote_out"
grep -Fq "root commit=$root_updated branch=main" "$remote_out"
grep -Fq "submodule path=module-a pin=$sub_pin head=$sub_branch_head" "$remote_out"
test "$(git -C "$tmp_dir/remote-checkout/module-a" rev-parse HEAD)" = "$sub_branch_head"

printf 'remote checkout update OK\n'
