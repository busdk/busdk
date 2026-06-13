#!/usr/bin/env sh
set -eu

script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
script_path="$script_dir/$(basename "$0")"

promote_ref_to_main() {
  repo_label=$1
  source_label=$2
  source_ref=$3
  original_branch="$(git symbolic-ref -q --short HEAD || true)"
  original_head="$(git rev-parse --verify HEAD)"
  source_commit="$(git rev-parse --verify "${source_ref}^{commit}")"

  restore_original_checkout() {
    if [ -n "$original_branch" ]; then
      git checkout -q "$original_branch"
    else
      git checkout -q "$original_head"
    fi
  }

  if ! git rev-parse --verify refs/heads/main >/dev/null; then
    if git rev-parse --verify refs/remotes/origin/main >/dev/null; then
      git branch --track main origin/main >/dev/null
    else
      echo "$repo_label: missing local main branch and origin/main; aborting" >&2
      exit 1
    fi
  fi

  main_before="$(git rev-parse refs/heads/main)"
  origin_main_ref=""
  if git rev-parse --verify refs/remotes/origin/main >/dev/null; then
    origin_main_ref="$(git rev-parse refs/remotes/origin/main)"
  fi

  git checkout -q main

  if git merge-base --is-ancestor HEAD "$source_commit"; then
    git rebase "$source_commit"
  elif git merge-base --is-ancestor "$source_commit" HEAD; then
    echo "$repo_label: main already contains $source_label at $source_commit"
  elif [ -n "$origin_main_ref" ] && [ "$main_before" != "$origin_main_ref" ] && git merge-base --is-ancestor "$origin_main_ref" "$source_commit"; then
    git rebase "$source_commit"
  else
    echo "$repo_label: main and $source_label have diverged; refusing to rewrite published main" >&2
    echo "$repo_label: merge or rebase main manually, then rerun publish" >&2
    restore_original_checkout
    exit 1
  fi

  main_after="$(git rev-parse HEAD)"
  if [ "$main_after" = "$main_before" ]; then
    echo "$repo_label: main unchanged at $main_after"
  else
    echo "$repo_label: moved main from $main_before to $main_after"
  fi
  restore_original_checkout
  git push origin main
}

if [ "${1:-}" = "--promote-current-repo" ]; then
  promote_ref_to_main "${2:-$(basename "$PWD")}" "current HEAD" HEAD
  exit 0
fi

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "working tree has uncommitted changes; aborting" >&2
  git status --short --untracked-files=normal >&2
  exit 1
fi

if [ "$(git symbolic-ref -q --short HEAD || true)" != "develop" ]; then
  echo "publish must run from the superproject develop branch; aborting" >&2
  exit 1
fi

git submodule foreach --recursive '
  if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
    echo "$name has uncommitted changes; aborting" >&2
    git status --short --untracked-files=normal >&2
    exit 1
  fi
'

make publish-preflight

if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  echo "working tree changed after tests; aborting" >&2
  git status --short --untracked-files=normal >&2
  exit 1
fi

git submodule sync --recursive
git submodule update --init --recursive

git submodule foreach --recursive '
  if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
    echo "$name has uncommitted changes; aborting" >&2
    git status --short --untracked-files=normal >&2
    exit 1
  fi
'

git submodule foreach --recursive "\"$script_path\" --promote-current-repo \"\$name\""
promote_ref_to_main "superproject" "develop" refs/heads/develop

latest_tag="$(git tag --list 'v*' --sort=-v:refname | { read -r first || true; printf '%s' "$first"; })"

if [ -z "$latest_tag" ]; then
  next_tag="v0.0.1"
else
  case "$latest_tag" in
    v[0-9]*.[0-9]*.[0-9]*)
      base="${latest_tag#v}"
      old_ifs="$IFS"
      IFS=.
      set -- $base
      IFS="$old_ifs"
      major="${1:-}"
      minor="${2:-}"
      patch="${3:-}"
      if [ -z "$major" ] || [ -z "$minor" ] || [ -z "$patch" ]; then
        echo "unsupported tag format: $latest_tag" >&2
        exit 1
      fi
      next_tag="v${major}.${minor}.$((patch + 1))"
      ;;
    *)
      echo "unsupported tag format: $latest_tag" >&2
      exit 1
      ;;
  esac
fi

if git rev-parse -q --verify "refs/tags/${next_tag}" >/dev/null; then
  echo "tag ${next_tag} already exists; aborting" >&2
  exit 1
fi

git tag "$next_tag"

git submodule foreach --recursive '
  set -eu
  TAG="'"$next_tag"'"
  HEAD_SHA="$(git rev-parse HEAD)"
  if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    TAG_SHA="$(git rev-parse "refs/tags/${TAG}")"
    if [ "$TAG_SHA" = "$HEAD_SHA" ]; then
      echo "$name: tag ${TAG} already exists at ${HEAD_SHA}"
      exit 0
    fi
    echo "$name: tag ${TAG} exists at ${TAG_SHA}, expected ${HEAD_SHA}" >&2
    exit 1
  fi
  git tag "${TAG}"
  git push origin "refs/tags/${TAG}"
  echo "$name: pushed tag ${TAG} at ${HEAD_SHA}"
'

git push origin "$next_tag"
echo "Created and pushed tag $next_tag (including submodules)"
