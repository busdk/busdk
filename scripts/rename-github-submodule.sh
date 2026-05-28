#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  scripts/rename-github-submodule.sh [options] <old-name> <new-name>

Renames a GitHub repository and the matching checked-out submodule in this
superproject. Dry-run is the default; pass --apply to mutate GitHub and local
Git metadata.

Examples:
  scripts/rename-github-submodule.sh bus-integration-dev-task bus-integration-task
  scripts/rename-github-submodule.sh --apply bus-integration-dev-task bus-integration-task
  scripts/rename-github-submodule.sh --apply --skip-github old-module new-module

Options:
  --apply              perform the rename; without this, print planned actions
  --owner OWNER        GitHub owner or organization (default: busdk)
  --old-path PATH      existing submodule path (default: <old-name>)
  --new-path PATH      new submodule path (default: <new-name>)
  --remote NAME        submodule remote to update (default: origin)
  --skip-github        do not rename the GitHub repository
  --skip-local         do not move/update the local submodule
  -h, --help           show this help

The script uses gh for the GitHub rename and git for all local submodule
metadata. It does not rewrite source imports, docs, dispatcher metadata, or
module-internal package names; run rg for the old name after the rename.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run() {
  if [ "$apply" -eq 1 ]; then
    printf '+'
    for arg in "$@"; do
      printf ' %s' "$(quote "$arg")"
    done
    printf '\n'
    "$@"
  else
    printf 'dry-run:'
    for arg in "$@"; do
      printf ' %s' "$(quote "$arg")"
    done
    printf '\n'
  fi
}

relpath() {
  from_dir=$1
  to_path=$2
  perl -MFile::Spec -e 'print File::Spec->abs2rel($ARGV[1], $ARGV[0])' "$from_dir" "$to_path"
}

find_submodule_section_by_path() {
  target_path=$1
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' |
    while IFS=' ' read -r key value; do
      if [ "$value" = "$target_path" ]; then
        section=${key#submodule.}
        section=${section%.path}
        printf '%s\n' "$section"
        return 0
      fi
    done
}

github_repo_exists() {
  repo=$1
  gh repo view "$repo" >/dev/null 2>&1
}

rename_github_repo() {
  old_repo=$1
  new_name=$2
  new_repo=$3

  if [ "$apply" -eq 0 ]; then
    owner=${old_repo%%/*}
    old_name=${old_repo#*/}
    run gh api -X PATCH "repos/$owner/$old_name" -f "name=$new_name"
    return 0
  fi

  if github_repo_exists "$new_repo"; then
    info "github: target already exists: $new_repo"
    if github_repo_exists "$old_repo"; then
      die "both source and target repositories exist on GitHub: $old_repo and $new_repo"
    fi
    return 0
  fi

  if ! github_repo_exists "$old_repo"; then
    die "source repository does not exist on GitHub and target is absent: $old_repo"
  fi

  owner=${old_repo%%/*}
  old_name=${old_repo#*/}
  run gh api -X PATCH "repos/$owner/$old_name" -f "name=$new_name"
}

apply_local_rename() {
  section=$1
  new_section=$2
  old_path=$3
  new_path=$4
  new_url=$5
  remote_name=$6
  old_admin_dir=
  new_admin_dir=
  new_gitfile_target=
  new_worktree_rel=
  admin_gitconfig=

  if [ ! -e "$old_path" ] && [ ! -e "$new_path" ]; then
    die "neither old nor new submodule path exists: $old_path, $new_path"
  fi

  old_admin_dir=$(git rev-parse --git-path "modules/$section")
  new_admin_dir=$(git rev-parse --git-path "modules/$new_section")

  if [ "$old_path" != "$new_path" ]; then
    if [ -e "$new_path" ]; then
      die "new path already exists: $new_path"
    fi
    run git mv "$old_path" "$new_path"
  fi

  if [ "$section" != "$new_section" ]; then
    if git config -f .gitmodules --get "submodule.$new_section.path" >/dev/null 2>&1; then
      die ".gitmodules already has section submodule.$new_section"
    fi
    run git config -f .gitmodules --rename-section "submodule.$section" "submodule.$new_section"
  fi

  run git config -f .gitmodules "submodule.$new_section.path" "$new_path"
  run git config -f .gitmodules "submodule.$new_section.url" "$new_url"
  run git config "submodule.$new_section.url" "$new_url"

  if [ "$section" != "$new_section" ] && git config --get "submodule.$section.url" >/dev/null 2>&1; then
    run git config --remove-section "submodule.$section"
  fi

  if [ "$old_admin_dir" != "$new_admin_dir" ] && [ -e "$old_admin_dir" ]; then
    if [ -e "$new_admin_dir" ]; then
      die "new submodule admin dir already exists: $new_admin_dir"
    fi
    run mkdir -p "$(dirname "$new_admin_dir")"
    run mv "$old_admin_dir" "$new_admin_dir"
  fi

  if [ "$apply" -eq 0 ] || [ -e "$new_admin_dir" ]; then
    new_gitfile_target=$(relpath "$repo_root/$new_path" "$new_admin_dir")
    new_worktree_rel=$(relpath "$new_admin_dir" "$repo_root/$new_path")
    admin_gitconfig=$new_admin_dir/config

    if [ "$apply" -eq 0 ] || [ -f "$new_path/.git" ]; then
      if [ "$apply" -eq 1 ]; then
        printf 'gitdir: %s\n' "$new_gitfile_target" >"$new_path/.git"
      else
        printf "dry-run: rewrite %s/.git -> gitdir: %s\n" "$(quote "$new_path")" "$(quote "$new_gitfile_target")"
      fi
    fi

    run git config -f "$admin_gitconfig" core.worktree "$new_worktree_rel"
  fi

  if [ "$apply" -eq 0 ] || [ -d "$new_path/.git" ] || [ -f "$new_path/.git" ]; then
    run git -C "$new_path" remote set-url "$remote_name" "$new_url"
    run git -C "$new_path" rev-parse --git-dir
  fi

  run git submodule sync -- "$new_path"
}

apply=0
owner=busdk
old_path=
new_path=
remote_name=origin
skip_github=0
skip_local=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --owner)
      [ "$#" -ge 2 ] || die "--owner requires a value"
      owner=$2
      shift 2
      ;;
    --owner=*)
      owner=${1#--owner=}
      shift
      ;;
    --old-path)
      [ "$#" -ge 2 ] || die "--old-path requires a value"
      old_path=$2
      shift 2
      ;;
    --old-path=*)
      old_path=${1#--old-path=}
      shift
      ;;
    --new-path)
      [ "$#" -ge 2 ] || die "--new-path requires a value"
      new_path=$2
      shift 2
      ;;
    --new-path=*)
      new_path=${1#--new-path=}
      shift
      ;;
    --remote)
      [ "$#" -ge 2 ] || die "--remote requires a value"
      remote_name=$2
      shift 2
      ;;
    --remote=*)
      remote_name=${1#--remote=}
      shift
      ;;
    --skip-github)
      skip_github=1
      shift
      ;;
    --skip-local)
      skip_local=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 2 ] || {
  usage
  exit 2
}

old_name=$1
new_name=$2

[ -n "$owner" ] || die "owner must not be empty"
[ -n "$old_name" ] || die "old name must not be empty"
[ -n "$new_name" ] || die "new name must not be empty"
[ "$old_name" != "$new_name" ] || die "old and new names must differ"

old_path=${old_path:-$old_name}
new_path=${new_path:-$new_name}
old_repo="$owner/$old_name"
new_repo="$owner/$new_name"
new_url="git@github.com:$owner/$new_name.git"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a Git work tree"
[ -f .gitmodules ] || die "missing .gitmodules in $repo_root"

if [ "$skip_github" -eq 0 ] && [ "$apply" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "'gh' not found"
  gh auth status -h github.com >/dev/null 2>&1 || die "gh is not authenticated for github.com"
fi

section=
old_url=
if [ "$skip_local" -eq 0 ]; then
  section=$(find_submodule_section_by_path "$old_path" || true)
  if [ -z "$section" ] && [ -e "$new_path" ]; then
    section=$(find_submodule_section_by_path "$new_path" || true)
  fi
  [ -n "$section" ] || die "could not find submodule section for path: $old_path"
  old_url=$(git config -f .gitmodules --get "submodule.$section.url" || true)
fi

cat <<EOF
Repository root: $repo_root
Mode:            $([ "$apply" -eq 1 ] && printf apply || printf dry-run)
GitHub:         $old_repo -> $new_repo
Submodule:      ${section:-<skipped>} path ${old_path} -> ${new_path}
Submodule URL:  ${old_url:-<skipped>} -> ${new_url}
EOF

if [ "$skip_github" -eq 0 ]; then
  rename_github_repo "$old_repo" "$new_name" "$new_repo"
else
  info "github: skipped"
fi

if [ "$skip_local" -eq 0 ]; then
  apply_local_rename "$section" "$new_name" "$old_path" "$new_path" "$new_url" "$remote_name"
else
  info "local: skipped"
fi

cat <<EOF

Next checks:
  git status --short --untracked-files=all
  git diff -- .gitmodules
  rg -n "$(printf '%s' "$old_name" | sed 's/[.[\*^$()+?{|]/\\&/g')" .

After reviewing source/docs references, commit the root .gitmodules and
submodule path changes together.
EOF
