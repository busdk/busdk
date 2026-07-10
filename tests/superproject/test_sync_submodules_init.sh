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
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-src" module-existing
printf 'root\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-existing scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null

git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"
git_config -C "$tmp_dir/root-src" remote add origin "$tmp_dir/root-origin.git"
git_config -C "$tmp_dir/root-src" push --quiet --set-upstream origin develop
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-checkout"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-checkout" submodule update --init module-existing >/dev/null

test "$(git -C "$tmp_dir/root-checkout" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout"
test "$(git -C "$tmp_dir/root-checkout/module-existing" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout/module-existing"

for module in module-new-a module-new-b; do
	GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-src" "$module"
done
git_config -C "$tmp_dir/root-src" add .gitmodules module-new-a module-new-b
git_config -C "$tmp_dir/root-src" commit -m 'add new submodules' >/dev/null
git_config -C "$tmp_dir/root-src" push --quiet
root_head="$(git -C "$tmp_dir/root-src" rev-parse HEAD)"

for module in module-new-a module-new-b; do
	if [ -e "$tmp_dir/root-checkout/$module" ]; then
		printf 'FAIL sync-submodules init: %s unexpectedly exists before superproject pull\n' "$module" >&2
		exit 1
	fi
	if git -C "$tmp_dir/root-checkout" config --file .gitmodules --get "submodule.$module.path" >/dev/null 2>&1; then
		printf 'FAIL sync-submodules init: %s unexpectedly registered before superproject pull\n' "$module" >&2
		exit 1
	fi
done

sync_out="$tmp_dir/sync.out"
GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-checkout/scripts/sync-submodules.sh" --pull-only --jobs 4 --verbose >"$sync_out"
grep -Fq 'syncing . [develop -> origin/develop] before submodules' "$sync_out"
grep -Fq 'syncing module-new-a [develop -> origin/develop]' "$sync_out"
grep -Fq 'syncing module-new-b [develop -> origin/develop]' "$sync_out"
grep -Fq 'sync-submodules: ok=4 skipped=0 failed=0 total=4' "$sync_out"

test "$(git -C "$tmp_dir/root-checkout" rev-parse HEAD)" = "$root_head"
for module in module-new-a module-new-b; do
	test "$(git -C "$tmp_dir/root-checkout" config --file .gitmodules --get "submodule.$module.path")" = "$module"
	test "$(git -C "$tmp_dir/root-checkout/$module" rev-parse --show-toplevel)" = "$tmp_dir/root-checkout/$module"
	test "$(git -C "$tmp_dir/root-checkout/$module" rev-parse HEAD)" = "$sub_head"
	test "$(git -C "$tmp_dir/root-checkout/$module" branch --show-current)" = "develop"
done
test -z "$(git -C "$tmp_dir/root-checkout" status --porcelain)"

printf 'sync new submodules after pull OK\n'
