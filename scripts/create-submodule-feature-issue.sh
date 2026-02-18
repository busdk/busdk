#!/usr/bin/env bash
set -euo pipefail
#set -x
cd "$(dirname "$0")/.."

export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE_NOTIFIER=1

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "usage: $0 <repo-name>" >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: 'gh' not found" >&2
  exit 127
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "error: gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi

REPO="busdk/$NAME"

if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "error: repo does not exist: $REPO" >&2
  exit 1
fi

ISSUE_TITLE="Add a module ${NAME}"
ISSUE_BODY="SDD: https://docs.busdk.com/sdd/${NAME}"

echo "creating feature issue: $ISSUE_TITLE"
ISSUE_NUMBER="$(gh api -X POST "repos/$REPO/issues" \
  -f "title=$ISSUE_TITLE" \
  -f "body=$ISSUE_BODY" \
  --jq '.number')"
echo "created issue #$ISSUE_NUMBER"

DEFAULT_BRANCH="$(gh api "repos/$REPO" --jq '.default_branch')"
BRANCH="1-$NAME"

# If branch exists already, do nothing.
if gh api "repos/$REPO/git/ref/heads/$BRANCH" >/dev/null 2>&1; then
  echo "branch exists: $BRANCH"
  exit 0
fi

echo "creating branch: $BRANCH (from $DEFAULT_BRANCH)"

BASE_SHA=""
if BASE_SHA="$(gh api "repos/$REPO/git/ref/heads/$DEFAULT_BRANCH" --jq '.object.sha' 2>/dev/null)"; then
  :
else
  BASE_SHA=""
fi

if [[ -z "$BASE_SHA" ]]; then
  echo "repo is empty (or not ready); initializing default branch with README.md"

  README_CONTENT="$(printf '# %s\n\nSDD: https://docs.busdk.com/sdd/%s\n' "$NAME" "$NAME")"
  README_B64="$(printf '%s' "$README_CONTENT" | base64 | tr -d '\n')"

  # Retry because GitHub may still be creating the repo (409) for a moment. :contentReference[oaicite:3]{index=3}
  INIT_SHA=""
  for _ in {1..20}; do
    if INIT_SHA="$(gh api -X PUT "repos/$REPO/contents/README.md" \
        -f "message=chore: init repository" \
        -f "content=$README_B64" \
        -f "branch=$DEFAULT_BRANCH" \
        --jq '.commit.sha' 2>/dev/null)"; then
      break
    fi
    sleep 0.2
  done

  if [[ -z "$INIT_SHA" ]]; then
    echo "error: failed to initialize repo (still returning 409). Try again in a moment." >&2
    exit 1
  fi

  # Use the returned commit SHA instead of fetching refs again. :contentReference[oaicite:4]{index=4}
  BASE_SHA="$INIT_SHA"
fi

gh api -X POST "repos/$REPO/git/refs" \
  -f "ref=refs/heads/$BRANCH" \
  -f "sha=$BASE_SHA" >/dev/null

echo "created branch: $BRANCH"
