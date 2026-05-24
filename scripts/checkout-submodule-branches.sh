#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DRY_RUN=false
FORCE=false
FETCH=true
INIT=true
BRANCH_MAP=

usage() {
	cat <<'USAGE'
usage: checkout-submodule-branches.sh [options]

Initialize BusDK submodules and checkout each submodule to the branch declared
in .gitmodules. Most modules use 1-{module}; exceptions are read from
.gitmodules instead of guessed.

Options:
  --dry-run     Print the commands that would run without mutating checkouts.
  --force       Allow checkout when a submodule has local changes.
  --no-fetch    Do not fetch the configured branch from origin.
  --no-init     Do not run submodule sync/update before branch checkout.
  --branch-map FILE
                Read desired branches from scripts/list-submodules.sh output.
                The first column is the path and the third column is branch.
  -h, --help    Show this help.
USAGE
}

die() {
	printf 'checkout-submodule-branches: %s\n' "$*" >&2
	exit 2
}

quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

branch_from_map() {
	path=$1
	[ -n "$BRANCH_MAP" ] || return 1
	awk -v want="$path" '
		$1 == want && $3 != "" && $3 !~ /^\(/ {
			print $3
			found = 1
			exit
		}
		END { if (!found) exit 1 }
	' "$BRANCH_MAP"
}

run() {
	if [ "$DRY_RUN" = true ]; then
		printf '+'
		for arg do
			printf ' %s' "$(quote "$arg")"
		done
		printf '\n'
	else
		"$@"
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--dry-run) DRY_RUN=true; shift ;;
		--force) FORCE=true; shift ;;
		--no-fetch) FETCH=false; shift ;;
		--no-init) INIT=false; shift ;;
		--branch-map)
			[ "$#" -ge 2 ] || die "missing value for --branch-map"
			BRANCH_MAP=$2
			shift 2
			;;
		-h|--help) usage; exit 0 ;;
		*) die "unknown option: $1" ;;
	esac
done

cd "$ROOT"

if [ ! -f .gitmodules ]; then
	die ".gitmodules not found at $ROOT"
fi
if [ -n "$BRANCH_MAP" ] && [ ! -f "$BRANCH_MAP" ]; then
	die "branch map not found: $BRANCH_MAP"
fi

if [ "$INIT" = true ]; then
	run git -C "$ROOT" submodule sync --recursive
	run git -C "$ROOT" submodule update --init --recursive
fi

git config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
while read -r key path; do
	name=$(printf '%s' "$key" | sed 's/^submodule\.//; s/\.path$//')
	branch=$(branch_from_map "$path" || git config --file .gitmodules --get "submodule.$name.branch" || true)
	if [ -z "$branch" ]; then
		printf 'skip %s: no branch configured\n' "$path"
		continue
	fi
	if [ ! -d "$path/.git" ] && [ ! -f "$path/.git" ]; then
		die "submodule $path is not initialized"
	fi

	dirty=$(git -C "$path" status --porcelain)
	if [ -n "$dirty" ] && [ "$FORCE" != true ]; then
		printf 'dirty submodule %s; commit, stash, or rerun with --force\n' "$path" >&2
		printf '%s\n' "$dirty" >&2
		exit 3
	fi

	if [ "$FETCH" = true ]; then
		run git -C "$path" fetch origin "$branch"
	fi

	if git -C "$path" show-ref --verify --quiet "refs/heads/$branch"; then
		run git -C "$path" checkout "$branch"
	elif git -C "$path" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		run git -C "$path" checkout -b "$branch" --track "origin/$branch"
	else
		printf 'warning: %s has no origin/%s; creating local branch from current HEAD\n' "$path" "$branch" >&2
		run git -C "$path" checkout -b "$branch"
	fi

	if git -C "$path" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		run git -C "$path" branch --set-upstream-to="origin/$branch" "$branch"
		run git -C "$path" merge --ff-only "origin/$branch"
	fi

	if [ "$DRY_RUN" = true ]; then
		current=$branch
	else
		current=$(git -C "$path" branch --show-current)
	fi
	printf '%-27s %s\n' "$path" "$current"
done
