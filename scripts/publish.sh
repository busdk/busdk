#!/usr/bin/env sh
set -eu

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree has uncommitted changes; aborting" >&2
  exit 1
fi

make test

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "working tree changed after tests; aborting" >&2
  exit 1
fi

git submodule sync --recursive
git submodule update --init --recursive

git submodule foreach --recursive '
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "$name has uncommitted changes; aborting" >&2
    exit 1
  fi
'

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
