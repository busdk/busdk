#!/bin/sh
set -eu

usage() {
  printf '%s\n' "usage: scripts/commit-tracker-only.sh <repo-path> <commit-message> <tracker-file> [<tracker-file> ...]" >&2
  printf '%s\n' "allowed tracker files: PLAN.md BUGS.md FEATURE_REQUESTS.md" >&2
}

if [ "$#" -lt 3 ]; then
  usage
  exit 2
fi

repo_path=$1
commit_message=$2
shift 2

if [ ! -d "$repo_path/.git" ] && [ ! -f "$repo_path/.git" ]; then
  printf 'not a git repository: %s\n' "$repo_path" >&2
  exit 1
fi

trackers=
for tracker in "$@"; do
  case "$tracker" in
    PLAN.md|BUGS.md|FEATURE_REQUESTS.md)
      ;;
    *)
      printf 'unsupported tracker file: %s\n' "$tracker" >&2
      usage
      exit 2
      ;;
  esac

  if [ ! -f "$repo_path/$tracker" ]; then
    printf 'missing %s in repository: %s\n' "$tracker" "$repo_path" >&2
    exit 1
  fi

  if [ -z "${trackers}" ]; then
    trackers=$tracker
  else
    trackers="$trackers $tracker"
  fi
done

# shellcheck disable=SC2086
git -C "$repo_path" add -- $trackers
# shellcheck disable=SC2086
git -C "$repo_path" commit --only -m "$commit_message" -- $trackers

