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
printf 'parent_head=%s\nparent_pin=%s\nchild_head=%s\nverified=clean-ahead-promoted\n' \
	"$(git -C "$tmp_dir/root-candidate" rev-parse HEAD)" \
	"$(git -C "$tmp_dir/root-candidate" rev-parse HEAD:module-a)" \
	"$(git -C "$tmp_dir/root-candidate/module-a" rev-parse HEAD)" >"$tmp_dir/clean-ahead.state"

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
printf 'parent_head=%s\nparent_pin=%s\nchild_head=%s\nverified=modified-child-refused\n' \
	"$(git -C "$tmp_dir/root-baseline" rev-parse HEAD)" \
	"$(git -C "$tmp_dir/root-baseline" rev-parse :module-a)" \
	"$(git -C "$tmp_dir/root-baseline/module-a" rev-parse HEAD)" >"$tmp_dir/modified-child.state"

GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-rebase"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-rebase" submodule update --init --quiet
git_config -C "$tmp_dir/root-rebase/module-a" checkout --quiet develop
test "$(git -C "$tmp_dir/root-rebase/module-a" rev-parse HEAD)" = "$(git -C "$tmp_dir/root-rebase" rev-parse HEAD:module-a)"
rebase_git_dir="$(git -C "$tmp_dir/root-rebase/module-a" rev-parse --absolute-git-dir)"
mkdir "$rebase_git_dir/rebase-merge"
: >"$rebase_git_dir/CHERRY_PICK_HEAD"
test -z "$(record_status "$tmp_dir/root-rebase/module-a")"
test -z "$(record_status "$tmp_dir/root-rebase")"
git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-rebase-upstream"
printf 'upstream before operation refusal\n' >>"$tmp_dir/root-rebase-upstream/README.md"
git_config -C "$tmp_dir/root-rebase-upstream" add README.md
git_config -C "$tmp_dir/root-rebase-upstream" commit -m 'parent upstream before operation refusal' >/dev/null
git_config -C "$tmp_dir/root-rebase-upstream" push --quiet origin develop
rebase_parent_head="$(git -C "$tmp_dir/root-rebase" rev-parse HEAD)"
rebase_parent_ref="$(git -C "$tmp_dir/root-rebase" rev-parse refs/remotes/origin/develop)"
rebase_parent_index="$(git -C "$tmp_dir/root-rebase" write-tree)"
rebase_child_head="$(git -C "$tmp_dir/root-rebase/module-a" rev-parse HEAD)"
rebase_child_status="$(record_status "$tmp_dir/root-rebase/module-a")"
rebase_child_content="$(cat "$tmp_dir/root-rebase/module-a/module.txt")"
rebase_out="$tmp_dir/rebase-operation-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-rebase/scripts/sync-submodules.sh" --jobs 1 --verbose >"$rebase_out" 2>&1; then
	cat "$rebase_out" >&2
	exit 1
fi
grep -Fq 'warning: cannot pull superproject first: submodule module-a has merge/rebase/cherry-pick in progress' "$rebase_out"
test "$(git -C "$tmp_dir/root-rebase" rev-parse HEAD)" = "$rebase_parent_head"
test "$(git -C "$tmp_dir/root-rebase" rev-parse refs/remotes/origin/develop)" = "$rebase_parent_ref"
test "$(git -C "$tmp_dir/root-rebase" write-tree)" = "$rebase_parent_index"
test "$(git -C "$tmp_dir/root-rebase/module-a" rev-parse HEAD)" = "$rebase_child_head"
test "$(record_status "$tmp_dir/root-rebase/module-a")" = "$rebase_child_status"
test "$(cat "$tmp_dir/root-rebase/module-a/module.txt")" = "$rebase_child_content"
test -d "$rebase_git_dir/rebase-merge"
test -f "$rebase_git_dir/CHERRY_PICK_HEAD"
printf 'parent_head=%s\nremote_ref=%s\nindex_tree=%s\nchild_head=%s\nverified=operation-refused-before-pull\n' \
	"$rebase_parent_head" "$rebase_parent_ref" "$rebase_parent_index" "$rebase_child_head" >"$tmp_dir/rebase-operation.state"

GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-untracked"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-untracked" submodule update --init --quiet
git_config -C "$tmp_dir/root-untracked/module-a" checkout --quiet develop
printf 'module second update\n' >>"$tmp_dir/sub-work/module.txt"
git_config -C "$tmp_dir/sub-work" add module.txt
git_config -C "$tmp_dir/sub-work" commit -m 'submodule second update' >/dev/null
untracked_child_head="$(git -C "$tmp_dir/sub-work" rev-parse HEAD)"
git_config -C "$tmp_dir/sub-work" push --quiet "$tmp_dir/sub-origin.git" develop
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/root-untracked/module-a" pull --ff-only --quiet
test -z "$(record_status "$tmp_dir/root-untracked/module-a")"
git_config clone --quiet "$tmp_dir/root-origin.git" "$tmp_dir/root-untracked-upstream"
printf 'upstream before untracked refusal\n' >>"$tmp_dir/root-untracked-upstream/README.md"
git_config -C "$tmp_dir/root-untracked-upstream" add README.md
git_config -C "$tmp_dir/root-untracked-upstream" commit -m 'parent upstream before untracked refusal' >/dev/null
git_config -C "$tmp_dir/root-untracked-upstream" push --quiet origin develop
printf 'unrelated\n' >"$tmp_dir/root-untracked/unrelated-root.txt"
untracked_parent_head="$(git -C "$tmp_dir/root-untracked" rev-parse HEAD)"
untracked_parent_ref="$(git -C "$tmp_dir/root-untracked" rev-parse refs/remotes/origin/develop)"
untracked_parent_index="$(git -C "$tmp_dir/root-untracked" write-tree)"
untracked_child_status="$(record_status "$tmp_dir/root-untracked/module-a")"
untracked_child_content="$(cat "$tmp_dir/root-untracked/module-a/module.txt")"
untracked_out="$tmp_dir/untracked-root-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/root-untracked/scripts/sync-submodules.sh" --jobs 1 --verbose >"$untracked_out" 2>&1; then
	cat "$untracked_out" >&2
	exit 1
fi
grep -Fq 'warning: cannot pull superproject first: superproject path unrelated-root.txt is untracked' "$untracked_out"
test "$(git -C "$tmp_dir/root-untracked" rev-parse HEAD)" = "$untracked_parent_head"
test "$(git -C "$tmp_dir/root-untracked" rev-parse refs/remotes/origin/develop)" = "$untracked_parent_ref"
test "$(git -C "$tmp_dir/root-untracked" write-tree)" = "$untracked_parent_index"
test "$(git -C "$tmp_dir/root-untracked/module-a" rev-parse HEAD)" = "$untracked_child_head"
test "$(record_status "$tmp_dir/root-untracked/module-a")" = "$untracked_child_status"
test "$(cat "$tmp_dir/root-untracked/module-a/module.txt")" = "$untracked_child_content"
printf 'parent_head=%s\nremote_ref=%s\nindex_tree=%s\nchild_head=%s\nverified=untracked-root-refused-before-pull\n' \
	"$untracked_parent_head" "$untracked_parent_ref" "$untracked_parent_index" "$untracked_child_head" >"$tmp_dir/untracked-root.state"

mkdir "$tmp_dir/staged-a-work" "$tmp_dir/staged-b-work"
for module in staged-a staged-b; do
	git_config -C "$tmp_dir/${module}-work" init -b develop >/dev/null
	printf '%s base\n' "$module" >"$tmp_dir/${module}-work/module.txt"
	git_config -C "$tmp_dir/${module}-work" add module.txt
	git_config -C "$tmp_dir/${module}-work" commit -m "$module base" >/dev/null
	git_config -C "$tmp_dir/${module}-work" clone --quiet --bare . "$tmp_dir/${module}-origin.git"
done
mkdir "$tmp_dir/staged-root-src"
git_config -C "$tmp_dir/staged-root-src" init -b develop >/dev/null
mkdir "$tmp_dir/staged-root-src/scripts"
cp "$root_dir/scripts/sync-submodules.sh" "$tmp_dir/staged-root-src/scripts/sync-submodules.sh"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/staged-root-src" submodule add --quiet -b develop "$tmp_dir/staged-a-origin.git" module-a
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/staged-root-src" submodule add --quiet -b develop "$tmp_dir/staged-b-origin.git" module-b
printf 'staged root\n' >"$tmp_dir/staged-root-src/README.md"
git_config -C "$tmp_dir/staged-root-src" add .gitmodules README.md module-a module-b scripts
git_config -C "$tmp_dir/staged-root-src" commit -m 'staged root base' >/dev/null
git_config -C "$tmp_dir/staged-root-src" clone --quiet --bare . "$tmp_dir/staged-root-origin.git"
GIT_ALLOW_PROTOCOL=file git_config clone --quiet "$tmp_dir/staged-root-origin.git" "$tmp_dir/staged-root"
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/staged-root" submodule update --init --quiet
git_config -C "$tmp_dir/staged-root/module-a" checkout --quiet develop
git_config -C "$tmp_dir/staged-root/module-b" checkout --quiet develop
for module in staged-a staged-b; do
	printf '%s update\n' "$module" >>"$tmp_dir/${module}-work/module.txt"
	git_config -C "$tmp_dir/${module}-work" add module.txt
	git_config -C "$tmp_dir/${module}-work" commit -m "$module update" >/dev/null
	git_config -C "$tmp_dir/${module}-work" push --quiet "$tmp_dir/${module}-origin.git" develop
done
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/staged-root/module-a" pull --ff-only --quiet
GIT_ALLOW_PROTOCOL=file git_config -C "$tmp_dir/staged-root/module-b" pull --ff-only --quiet
git_config -C "$tmp_dir/staged-root" add module-a
git_config -C "$tmp_dir/staged-root" config submodule.module-a.ignore all
git_config clone --quiet "$tmp_dir/staged-root-origin.git" "$tmp_dir/staged-root-upstream"
printf 'upstream before staged refusal\n' >>"$tmp_dir/staged-root-upstream/README.md"
git_config -C "$tmp_dir/staged-root-upstream" add README.md
git_config -C "$tmp_dir/staged-root-upstream" commit -m 'parent upstream before staged refusal' >/dev/null
git_config -C "$tmp_dir/staged-root-upstream" push --quiet origin develop
staged_parent_head="$(git -C "$tmp_dir/staged-root" rev-parse HEAD)"
staged_parent_ref="$(git -C "$tmp_dir/staged-root" rev-parse refs/remotes/origin/develop)"
staged_parent_index="$(git -C "$tmp_dir/staged-root" write-tree)"
staged_a_head="$(git -C "$tmp_dir/staged-root/module-a" rev-parse HEAD)"
staged_b_head="$(git -C "$tmp_dir/staged-root/module-b" rev-parse HEAD)"
staged_a_status="$(record_status "$tmp_dir/staged-root/module-a")"
staged_b_status="$(record_status "$tmp_dir/staged-root/module-b")"
staged_out="$tmp_dir/hidden-staged-sync.out"
if GIT_ALLOW_PROTOCOL=file "$tmp_dir/staged-root/scripts/sync-submodules.sh" --jobs 1 --verbose >"$staged_out" 2>&1; then
	cat "$staged_out" >&2
	exit 1
fi
grep -Fq 'warning: cannot pull superproject first: submodule module-a has staged gitlink changes' "$staged_out"
test "$(git -C "$tmp_dir/staged-root" rev-parse HEAD)" = "$staged_parent_head"
test "$(git -C "$tmp_dir/staged-root" rev-parse refs/remotes/origin/develop)" = "$staged_parent_ref"
test "$(git -C "$tmp_dir/staged-root" write-tree)" = "$staged_parent_index"
test "$(git -C "$tmp_dir/staged-root/module-a" rev-parse HEAD)" = "$staged_a_head"
test "$(git -C "$tmp_dir/staged-root/module-b" rev-parse HEAD)" = "$staged_b_head"
test "$(record_status "$tmp_dir/staged-root/module-a")" = "$staged_a_status"
test "$(record_status "$tmp_dir/staged-root/module-b")" = "$staged_b_status"
printf 'parent_head=%s\nremote_ref=%s\nindex_tree=%s\nmodule_a_head=%s\nmodule_b_head=%s\nverified=hidden-staged-gitlink-refused-before-pull\n' \
	"$staged_parent_head" "$staged_parent_ref" "$staged_parent_index" "$staged_a_head" "$staged_b_head" >"$tmp_dir/hidden-staged.state"

printf 'sync submodules default clean-ahead OK\n'
