#!/usr/bin/env sh
set -eu

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree has uncommitted changes; aborting" >&2
  exit 1
fi

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

git tag "$next_tag"
echo "Created tag $next_tag"
echo "Push with: git push origin $next_tag"
