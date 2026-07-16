#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/worktrees/sync-submodules-default-clean-ahead-test.$$"
if [ "${KEEP_THREAD200_FIXTURE:-0}" = 1 ]; then
	trap 'printf "sync submodules default clean-ahead fixture retained at %s\\n" "$tmp_dir"' EXIT
else
	trap 'rm -rf "$tmp_dir"' EXIT
fi

mkdir -p "$tmp_dir"

git_config() {
	git -c user.name='BusDK Test' -c user.email='busdk-test@example.invalid' "$@"
}

record_status() {
	git -C "$1" status --porcelain
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
sed '/if ! superproject_is_clean_or_has_only_safe_submodule_drift; then/c\
  if is_dirty "."; then\
    echo "warning: cannot pull superproject first: working tree has uncommitted changes" >&2' \
	"$root_dir/scripts/sync-submodules.sh" >"$tmp_dir/root-src/scripts/sync-submodules-baseline.sh"
chmod +x "$tmp_dir/root-src/scripts/sync-submodules.sh" "$tmp_dir/root-src/scripts/sync-submodules-baseline.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-src" submodule add --quiet -b develop "$tmp_dir/sub-origin.git" module-a
printf 'root\n' >"$tmp_dir/root-src/README.md"
git_config -C "$tmp_dir/root-src" add .gitmodules README.md module-a scripts
git_config -C "$tmp_dir/root-src" commit -m 'root base' >/dev/null
git_config -C "$tmp_dir/root-src" clone --quiet --bare . "$tmp_dir/root-origin.git"

GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-baseline"
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-candidate"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-baseline" submodule update --init --quiet
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-candidate" submodule update --init --quiet
git_config -C "$tmp_dir/root-baseline/module-a" checkout --quiet develop
git_config -C "$tmp_dir/root-candidate/module-a" checkout --quiet develop

printf 'module updated\n' >"$tmp_dir/sub-work/module.txt"
git_config -C "$tmp_dir/sub-work" add module.txt
git_config -C "$tmp_dir/sub-work" commit -m 'submodule update' >/dev/null
sub_head="$(git -C "$tmp_dir/sub-work" rev-parse HEAD)"
git_config -C "$tmp_dir/sub-work" push --quiet "$tmp_dir/sub-origin.git" develop

GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-baseline/module-a" pull --ff-only --quiet
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-candidate/module-a" pull --ff-only --quiet
test -z "$(record_status "$tmp_dir/root-baseline/module-a")"
test -z "$(record_status "$tmp_dir/root-candidate/module-a")"
test "$(git -C "$tmp_dir/root-baseline" diff --name-only)" = module-a
test "$(git -C "$tmp_dir/root-candidate" diff --name-only)" = module-a

baseline_parent_head="$(git -C "$tmp_dir/root-baseline" rev-parse HEAD)"
baseline_index="$(git -C "$tmp_dir/root-baseline" rev-parse :module-a)"
baseline_child_head="$(git -C "$tmp_dir/root-baseline/module-a" rev-parse HEAD)"
baseline_status="$(record_status "$tmp_dir/root-baseline")"
baseline_out="$tmp_dir/baseline-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-baseline/scripts/sync-submodules-baseline.sh" --jobs 1 --verbose >"$baseline_out" 2>&1; then
	cat "$baseline_out" >&2
	exit 1
fi
grep -Fq 'warning: cannot pull superproject first: working tree has uncommitted changes' "$baseline_out"
grep -Fq 'sync-submodules: ok=0 skipped=0 failed=1 total=2' "$baseline_out"
test "$(git -C "$tmp_dir/root-baseline" rev-parse HEAD)" = "$baseline_parent_head"
test "$(git -C "$tmp_dir/root-baseline" rev-parse :module-a)" = "$baseline_index"
test "$(git -C "$tmp_dir/root-baseline/module-a" rev-parse HEAD)" = "$baseline_child_head"
test "$(record_status "$tmp_dir/root-baseline")" = "$baseline_status"

candidate_out="$tmp_dir/candidate-sync.out"
GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-candidate/scripts/sync-submodules.sh" --jobs 1 --verbose >"$candidate_out" 2>&1
grep -Fq 'sync-submodules: staged 1 submodule pin(s); commit the superproject to record them.' "$candidate_out"
grep -Fq 'sync-submodules: ok=2 skipped=0 failed=0 total=2' "$candidate_out"
test "$(git -C "$tmp_dir/root-candidate/module-a" rev-parse HEAD)" = "$sub_head"
test "$(git -C "$tmp_dir/root-candidate" rev-parse HEAD:module-a)" = "$sub_head"
test -z "$(record_status "$tmp_dir/root-candidate")"
test "$(git -C "$tmp_dir/root-origin.git" rev-parse develop:module-a)" = "$sub_head"

printf 'modified locally\n' >>"$tmp_dir/root-baseline/module-a/module.txt"
modified_parent_head="$(git -C "$tmp_dir/root-baseline" rev-parse HEAD)"
modified_index="$(git -C "$tmp_dir/root-baseline" rev-parse :module-a)"
modified_child_head="$(git -C "$tmp_dir/root-baseline/module-a" rev-parse HEAD)"
modified_child_status="$(record_status "$tmp_dir/root-baseline/module-a")"
modified_content="$(cat "$tmp_dir/root-baseline/module-a/module.txt")"
modified_out="$tmp_dir/modified-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-baseline/scripts/sync-submodules.sh" --jobs 1 --verbose >"$modified_out" 2>&1; then
	cat "$modified_out" >&2
	exit 1
fi
grep -Fq 'warning: cannot pull superproject first: submodule module-a has uncommitted or untracked changes' "$modified_out"
grep -Fq 'sync-submodules: ok=0 skipped=0 failed=1 total=2' "$modified_out"
test "$(git -C "$tmp_dir/root-baseline" rev-parse HEAD)" = "$modified_parent_head"
test "$(git -C "$tmp_dir/root-baseline" rev-parse :module-a)" = "$modified_index"
test "$(git -C "$tmp_dir/root-baseline/module-a" rev-parse HEAD)" = "$modified_child_head"
test "$(record_status "$tmp_dir/root-baseline/module-a")" = "$modified_child_status"
test "$(cat "$tmp_dir/root-baseline/module-a/module.txt")" = "$modified_content"

printf 'sync submodules default clean-ahead OK\n'
