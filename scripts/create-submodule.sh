#!/usr/bin/env bash
set -euo pipefail
set -x
cd "$(dirname "$0")/.."

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

# If it exists already, do nothing.
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "repo exists: $REPO"
  exit 0
fi

echo "creating private repo: $REPO"
gh repo create "$REPO" --private --confirm
echo "created: $REPO"
