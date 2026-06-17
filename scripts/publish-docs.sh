#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
superproject_dir="$(CDPATH= cd "$script_dir/.." && pwd)"
docs_repo="$superproject_dir/docs"
docs_label="docs.busdk.com"
source_ref="${BUSDK_DOCS_SOURCE_REF:-refs/heads/develop}"
tmp_parent=""
tmp_worktree=""

die() {
  echo "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$tmp_worktree" ] && [ -e "$tmp_worktree/.git" ]; then
    git -C "$docs_repo" worktree remove --force "$tmp_worktree" >/dev/null 2>&1 || true
  fi
  if [ -n "$tmp_parent" ] && [ -d "$tmp_parent" ]; then
    rm -rf "$tmp_parent"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

[ -d "$docs_repo" ] || die "$docs_label repository not found at $docs_repo"

if ! git -C "$docs_repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "$docs_label is not a git repository: $docs_repo"
fi

if [ -n "$(git -C "$docs_repo" status --porcelain --untracked-files=normal)" ]; then
  echo "$docs_label has uncommitted changes; aborting" >&2
  git -C "$docs_repo" status --short --untracked-files=normal >&2
  exit 1
fi

if ! source_commit="$(git -C "$docs_repo" rev-parse --verify "${source_ref}^{commit}" 2>/dev/null)"; then
  die "$docs_label source ref not found: $source_ref"
fi

tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/busdk-publish-docs.XXXXXX")"
tmp_worktree="$tmp_parent/$docs_label"

git -C "$docs_repo" worktree add --detach "$tmp_worktree" "$source_commit" >/dev/null
git -C "$tmp_worktree" fetch origin +refs/heads/main:refs/remotes/origin/main

if ! remote_main="$(git -C "$tmp_worktree" rev-parse --verify refs/remotes/origin/main^{commit} 2>/dev/null)"; then
  die "$docs_label: missing origin/main; aborting"
fi

if git -C "$tmp_worktree" merge-base --is-ancestor "$remote_main" "$source_commit"; then
  if [ "$remote_main" = "$source_commit" ]; then
    echo "$docs_label: origin/main already at $source_commit"
  else
    git -C "$tmp_worktree" push origin "${source_commit}:refs/heads/main"
    echo "$docs_label: moved origin/main from $remote_main to $source_commit"
  fi
elif git -C "$tmp_worktree" merge-base --is-ancestor "$source_commit" "$remote_main"; then
  echo "$docs_label: origin/main already contains $source_ref at $source_commit"
else
  die "$docs_label: origin/main and $source_ref have diverged; refusing to rewrite published main"
fi
