#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
superproject_dir="$(CDPATH= cd "$script_dir/.." && pwd)"
website_repo="$superproject_dir/busdk.com"
website_label="busdk.com"
source_ref="${BUSDK_WEBSITE_SOURCE_REF:-refs/heads/develop}"
tmp_parent=""
tmp_worktree=""

die() {
  echo "$*" >&2
  exit 1
}

cleanup() {
  if [ -n "$tmp_worktree" ] && [ -e "$tmp_worktree/.git" ]; then
    git -C "$website_repo" worktree remove --force "$tmp_worktree" >/dev/null 2>&1 || true
  fi
  if [ -n "$tmp_parent" ] && [ -d "$tmp_parent" ]; then
    rm -rf "$tmp_parent"
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

[ -d "$website_repo" ] || die "$website_label repository not found at $website_repo"

if ! git -C "$website_repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "$website_label is not a git repository: $website_repo"
fi

if [ -n "$(git -C "$website_repo" status --porcelain --untracked-files=normal)" ]; then
  echo "$website_label has uncommitted changes; aborting" >&2
  git -C "$website_repo" status --short --untracked-files=normal >&2
  exit 1
fi

if ! source_commit="$(git -C "$website_repo" rev-parse --verify "${source_ref}^{commit}" 2>/dev/null)"; then
  die "$website_label source ref not found: $source_ref"
fi

tmp_parent="$(mktemp -d "${TMPDIR:-/tmp}/busdk-publish-website.XXXXXX")"
tmp_worktree="$tmp_parent/$website_label"

git -C "$website_repo" worktree add --detach "$tmp_worktree" "$source_commit" >/dev/null
git -C "$tmp_worktree" fetch origin +refs/heads/main:refs/remotes/origin/main

if ! remote_main="$(git -C "$tmp_worktree" rev-parse --verify refs/remotes/origin/main^{commit} 2>/dev/null)"; then
  die "$website_label: missing origin/main; aborting"
fi

if git -C "$tmp_worktree" merge-base --is-ancestor "$remote_main" "$source_commit"; then
  if [ "$remote_main" = "$source_commit" ]; then
    echo "$website_label: origin/main already at $source_commit"
  else
    git -C "$tmp_worktree" push origin "${source_commit}:refs/heads/main"
    echo "$website_label: moved origin/main from $remote_main to $source_commit"
  fi
elif git -C "$tmp_worktree" merge-base --is-ancestor "$source_commit" "$remote_main"; then
  echo "$website_label: origin/main already contains $source_ref at $source_commit"
else
  die "$website_label: origin/main and $source_ref have diverged; refusing to rewrite published main"
fi
