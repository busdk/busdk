#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REMOTE=${BUS_REMOTE_CHECKOUT_REMOTE:-origin}
BRANCH=${BUS_REMOTE_CHECKOUT_BRANCH:-}
REF=${BUS_REMOTE_CHECKOUT_REF:-}
FETCH=true
DRY_RUN=false
STATUS=false
ALL_SUBMODULES=false
SUBMODULE_MODE=pins
SUBMODULES=

usage() {
	cat <<'USAGE'
usage: remote-checkout-update.sh [options] [submodule-path ...]

Fetch and fast-forward a BusDK superproject checkout, then hydrate selected
submodules. Submodules are updated to checked-in superproject pins by default.
Use --submodule-mode remote only when branch-head submodule checkout is intended.

Options:
  --root DIR                 Superproject checkout to update.
  --remote NAME              Git remote to fetch from (default: origin).
  --branch NAME              Fast-forward local branch from REMOTE/NAME.
  --ref REF                  Fast-forward current HEAD to REF, then detach.
  --no-fetch                 Resolve branch/ref from existing refs only.
  --submodule PATH           Hydrate one submodule path; may be repeated.
  --all-submodules           Hydrate every submodule declared in .gitmodules.
  --submodule-mode MODE      pins (default) or remote.
  --status                   Print current root/submodule commits without changes.
  --dry-run                  Print commands without changes, then current status.
  -h, --help                 Show this help.
USAGE
}

die() {
	printf 'remote-checkout-update: %s\n' "$*" >&2
	exit 2
}

quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
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

submodule_paths() {
	git -C "$ROOT" config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
		awk '{ print $2 }'
}

is_submodule_path() {
	want=$1
	submodule_paths | awk -v want="$want" '$1 == want { found = 1 } END { exit found ? 0 : 1 }'
}

append_submodule() {
	path=$1
	if [ -z "$SUBMODULES" ]; then
		SUBMODULES=$path
	else
		SUBMODULES="$SUBMODULES $path"
	fi
}

current_branch() {
	branch=$(git -C "$ROOT" branch --show-current)
	if [ -n "$branch" ]; then
		printf '%s\n' "$branch"
	else
		printf 'detached\n'
	fi
}

report_status() {
	root_commit=$(git -C "$ROOT" rev-parse HEAD)
	root_branch=$(current_branch)
	printf 'root commit=%s branch=%s\n' "$root_commit" "$root_branch"

	for path in $SUBMODULES; do
		pin=$(git -C "$ROOT" ls-tree HEAD "$path" | awk '{ print $3 }')
		if [ -d "$ROOT/$path/.git" ] || [ -f "$ROOT/$path/.git" ]; then
			head=$(git -C "$ROOT/$path" rev-parse HEAD)
		else
			head=uninitialized
		fi
		printf 'submodule path=%s pin=%s head=%s\n' "$path" "$pin" "$head"
	done
}

check_root_clean() {
	dirty=$(git -C "$ROOT" status --porcelain --ignore-submodules=all)
	if [ -n "$dirty" ]; then
		printf 'remote-checkout-update: root checkout has local changes\n' >&2
		printf '%s\n' "$dirty" >&2
		exit 3
	fi
}

check_submodules_clean() {
	for path in $SUBMODULES; do
		if [ -d "$ROOT/$path/.git" ] || [ -f "$ROOT/$path/.git" ]; then
			dirty=$(git -C "$ROOT/$path" status --porcelain)
			if [ -n "$dirty" ]; then
				printf 'remote-checkout-update: submodule %s has local changes\n' "$path" >&2
				printf '%s\n' "$dirty" >&2
				exit 3
			fi
		fi
	done
}

update_branch() {
	branch=$1
	if [ "$FETCH" = true ]; then
		run git -C "$ROOT" fetch --quiet "$REMOTE" "$branch"
		target=FETCH_HEAD
	else
		if git -C "$ROOT" rev-parse --verify --quiet "$REMOTE/$branch^{commit}" >/dev/null; then
			target=$REMOTE/$branch
		else
			target=$branch
		fi
	fi

	if [ "$DRY_RUN" = true ]; then
		run git -C "$ROOT" checkout --quiet "$branch"
		run git -C "$ROOT" merge --quiet --ff-only "$target"
		return
	fi

	target_commit=$(git -C "$ROOT" rev-parse "$target^{commit}")
	if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
		branch_commit=$(git -C "$ROOT" rev-parse "$branch^{commit}")
		if ! git -C "$ROOT" merge-base --is-ancestor "$branch_commit" "$target_commit"; then
			die "local branch $branch is not an ancestor of $REMOTE/$branch"
		fi
		run git -C "$ROOT" checkout --quiet "$branch"
		run git -C "$ROOT" merge --quiet --ff-only "$target_commit"
	else
		run git -C "$ROOT" checkout --quiet -b "$branch" "$target_commit"
	fi
}

update_ref() {
	ref=$1
	if [ "$FETCH" = true ]; then
		run git -C "$ROOT" fetch --quiet "$REMOTE" "$ref"
		target=FETCH_HEAD
	else
		target=$ref
	fi

	if [ "$DRY_RUN" = true ]; then
		run git -C "$ROOT" checkout --quiet --detach "$target"
		return
	fi

	target_commit=$(git -C "$ROOT" rev-parse "$target^{commit}")
	current_commit=$(git -C "$ROOT" rev-parse HEAD)
	if ! git -C "$ROOT" merge-base --is-ancestor "$current_commit" "$target_commit"; then
		die "current HEAD is not an ancestor of requested ref $ref"
	fi
	run git -C "$ROOT" checkout --quiet --detach "$target_commit"
}

update_submodules() {
	[ -n "$SUBMODULES" ] || return 0
	check_submodules_clean

	set -- $SUBMODULES
	run git -C "$ROOT" submodule sync --quiet --recursive -- "$@"
	case "$SUBMODULE_MODE" in
		pins)
			run git -C "$ROOT" submodule update --quiet --init --recursive -- "$@"
			;;
		remote)
			run git -C "$ROOT" submodule update --quiet --init --recursive --remote -- "$@"
			;;
	esac
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--root)
			[ "$#" -ge 2 ] || die "missing value for --root"
			ROOT=$2
			shift 2
			;;
		--remote)
			[ "$#" -ge 2 ] || die "missing value for --remote"
			REMOTE=$2
			shift 2
			;;
		--branch)
			[ "$#" -ge 2 ] || die "missing value for --branch"
			BRANCH=$2
			shift 2
			;;
		--ref)
			[ "$#" -ge 2 ] || die "missing value for --ref"
			REF=$2
			shift 2
			;;
		--no-fetch) FETCH=false; shift ;;
		--submodule)
			[ "$#" -ge 2 ] || die "missing value for --submodule"
			append_submodule "$2"
			shift 2
			;;
		--all-submodules) ALL_SUBMODULES=true; shift ;;
		--submodule-mode)
			[ "$#" -ge 2 ] || die "missing value for --submodule-mode"
			SUBMODULE_MODE=$2
			shift 2
			;;
		--status) STATUS=true; FETCH=false; shift ;;
		--dry-run) DRY_RUN=true; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*) append_submodule "$1"; shift ;;
	esac
done

case "$SUBMODULE_MODE" in
	pins|remote) ;;
	*) die "invalid --submodule-mode: $SUBMODULE_MODE; expected pins or remote" ;;
esac

if [ -n "$BRANCH" ] && [ -n "$REF" ]; then
	die "use only one of --branch or --ref"
fi

if [ ! -d "$ROOT/.git" ] && [ ! -f "$ROOT/.git" ]; then
	die "not a git checkout: $ROOT"
fi

if [ ! -f "$ROOT/.gitmodules" ]; then
	die ".gitmodules not found at $ROOT"
fi

select_all_submodules() {
	if [ "$ALL_SUBMODULES" = true ]; then
		SUBMODULES=$(submodule_paths)
	fi
}

validate_submodules() {
	for path in $SUBMODULES; do
		if ! is_submodule_path "$path"; then
			die "unknown submodule path: $path"
		fi
	done
}

if [ "$STATUS" = true ]; then
	select_all_submodules
	validate_submodules
	report_status
	exit 0
fi

if [ -z "$BRANCH" ] && [ -z "$REF" ]; then
	die "missing --branch or --ref"
fi

check_root_clean

if [ -n "$BRANCH" ]; then
	update_branch "$BRANCH"
else
	update_ref "$REF"
fi

if [ ! -f "$ROOT/.gitmodules" ]; then
	die ".gitmodules not found after checkout at $ROOT"
fi

select_all_submodules
validate_submodules
update_submodules
report_status
