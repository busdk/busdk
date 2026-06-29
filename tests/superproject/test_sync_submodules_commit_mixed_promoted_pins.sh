#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-commit-mixed-promoted-pins-test.$$"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

create_submodule_origin() {
	local name="$1"
	mkdir "$tmp_dir/$name-work"
	git_config -C "$tmp_dir/$name-work" init -b develop >/dev/null
	printf '%s base\n' "$name" >"$tmp_dir/$name-work/module.txt"
	git_config -C "$tmp_dir/$name-work" add module.txt
	git_config -C "$tmp_dir/$name-work" commit -m "$name base" >/dev/null
	git_config -C "$tmp_dir/$name-work" clone --quiet --bare . "$tmp_dir/$name-origin.git"
}

update_submodule_origin() {
	local name="$1"
	printf '%s updated\n' "$name" >"$tmp_dir/$name-work/module.txt"
	git_config -C "$tmp_dir/$name-work" add module.txt
	git_config -C "$tmp_dir/$name-work" commit -m "$name update" >/dev/null
	git_config -C "$tmp_dir/$name-work" push --quiet "$tmp_dir/$name-origin.git" develop
	git -C "$tmp_dir/$name-work" rev-parse HEAD
}

checkout_submodule_head() {
	local module="$1"
	git_config -C "$tmp_dir/root-checkout/$module" fetch --quiet origin develop
	git_config -C "$tmp_dir/root-checkout/$module" checkout --quiet -B develop origin/develop
}

create_submodule_origin module-a
create_submodule_origin module-b

mkdir "$tmp_dir/root-src"
git_config -C "$tmp_dir/root-src" init -b develop >/dev/null
mkdir "$tmp_dir/root-src/scripts"
cp "$root_dir/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules.sh"
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/module-a-origin.git" module-a
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/module-b-origin.git" module-b
printf 'root\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a module-b scripts/sync-submodules.sh
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null
git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"

GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-checkout"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-checkout" submodule update --init module-a module-b >/dev/null

module_a_head="$(update_submodule_origin module-a)"
module_b_head="$(update_submodule_origin module-b)"
checkout_submodule_head module-a
checkout_submodule_head module-b

git_config -C "$tmp_dir/root-checkout" add module-a
test "$(git -C "$tmp_dir/root-checkout" status --porcelain -- module-a module-b)" = "$(printf 'M  module-a\n M module-b')"

sync_out="$tmp_dir/sync.out"
if ! GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-checkout/scripts/sync-submodules.sh" --push-only --jobs 1 --verbose . >"$sync_out"; then
	cat "$sync_out" >&2
	exit 1
fi

grep -Fq 'sync-submodules: ok=1 skipped=0 failed=0 total=1' "$sync_out"
if grep -Fq 'warning: skipping .: working tree has uncommitted changes' "$sync_out"; then
	cat "$sync_out" >&2
	exit 1
fi

test "$(git -C "$tmp_dir/root-checkout" rev-parse HEAD:module-a)" = "$module_a_head"
test "$(git -C "$tmp_dir/root-checkout" rev-parse HEAD:module-b)" = "$module_b_head"
test -z "$(git -C "$tmp_dir/root-checkout" status --porcelain)"
test "$(git -C "$tmp_dir/root-origin.git" rev-parse develop:module-a)" = "$module_a_head"
test "$(git -C "$tmp_dir/root-origin.git" rev-parse develop:module-b)" = "$module_b_head"

printf 'sync submodules commit mixed promoted pins OK\n'
