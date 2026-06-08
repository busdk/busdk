#!/bin/sh
set -eu

SSH_TARGET=${BUS_REMOTE_ENV_SYNC_SSH_TARGET:-}
REMOTE_ROOT=${BUS_REMOTE_ENV_SYNC_REMOTE_ROOT:-}
BRANCH=${BUS_REMOTE_ENV_SYNC_BRANCH:-develop}
ROOT_ORIGIN=${BUS_REMOTE_ENV_SYNC_ROOT_ORIGIN:-git@github.com:busdk/busdk.git}
SUBMODULE_MODE=${BUS_REMOTE_ENV_SYNC_SUBMODULE_MODE:-pins}
FETCH=${BUS_REMOTE_ENV_SYNC_FETCH:-true}
DRY_RUN=false
STATUS=false
CHECK_AGENT=true
ALL_SUBMODULES=true
SUBMODULES=

usage() {
	cat <<USAGE
usage: sync-remote-environment.sh --ssh-target TARGET --remote-root DIR [options] [submodule-path ...]

Synchronize a BusDK remote checkout without overwriting dirty primary
checkouts. The script enforces SSH agent forwarding, normalizes stale origin
URLs back to the canonical BusDK SSH URLs, fast-forwards clean checkouts, and
prints warnings for dirty or diverged folders that need manual repair.

Options:
  --ssh-target TARGET       SSH target, for example coding-agent@dev.hg.fi.
  --remote-root DIR         Remote BusDK superproject checkout path.
  --branch NAME             Root branch to fast-forward (default: $BRANCH).
  --root-origin URL         Expected root origin URL (default: $ROOT_ORIGIN).
  --submodule PATH          Sync one submodule path; may be repeated.
  --submodule-mode MODE     pins (default) or remote.
  --no-all-submodules       Only sync explicitly listed submodules.
  --no-fetch                Use existing remote refs only.
  --status                  Report state only; do not update checkouts.
  --dry-run                 Print planned remote mutations without running them.
  --no-agent-check          Skip local and remote ssh-agent checks.
  -h, --help                Show this help.

Environment defaults:
  BUS_REMOTE_ENV_SYNC_SSH_TARGET
  BUS_REMOTE_ENV_SYNC_REMOTE_ROOT
  BUS_REMOTE_ENV_SYNC_BRANCH
  BUS_REMOTE_ENV_SYNC_ROOT_ORIGIN
  BUS_REMOTE_ENV_SYNC_SUBMODULE_MODE
  BUS_REMOTE_ENV_SYNC_FETCH
USAGE
}

die() {
	printf 'sync-remote-environment: %s\n' "$*" >&2
	exit 2
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		die "missing value for $1"
	fi
}

append_submodule() {
	if [ -z "$SUBMODULES" ]; then
		SUBMODULES=$1
	else
		SUBMODULES="$SUBMODULES $1"
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--ssh-target) need_arg "$@"; SSH_TARGET=$2; shift 2 ;;
		--remote-root) need_arg "$@"; REMOTE_ROOT=$2; shift 2 ;;
		--branch) need_arg "$@"; BRANCH=$2; shift 2 ;;
		--root-origin) need_arg "$@"; ROOT_ORIGIN=$2; shift 2 ;;
		--submodule) need_arg "$@"; append_submodule "$2"; ALL_SUBMODULES=false; shift 2 ;;
		--submodule-mode) need_arg "$@"; SUBMODULE_MODE=$2; shift 2 ;;
		--no-all-submodules) ALL_SUBMODULES=false; shift ;;
		--no-fetch) FETCH=false; shift ;;
		--status) STATUS=true; FETCH=false; shift ;;
		--dry-run) DRY_RUN=true; shift ;;
		--no-agent-check) CHECK_AGENT=false; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*) append_submodule "$1"; ALL_SUBMODULES=false; shift ;;
	esac
done

case "$SUBMODULE_MODE" in
	pins|remote) ;;
	*) die "--submodule-mode must be pins or remote" ;;
esac
case "$FETCH" in
	true|false) ;;
	*) die "BUS_REMOTE_ENV_SYNC_FETCH must be true or false" ;;
esac

[ -n "$SSH_TARGET" ] || die "--ssh-target is required"
[ -n "$REMOTE_ROOT" ] || die "--remote-root is required"
[ -n "$BRANCH" ] || die "--branch must not be empty"
[ -n "$ROOT_ORIGIN" ] || die "--root-origin must not be empty"
command -v ssh >/dev/null 2>&1 || die "ssh is required"

if [ "$CHECK_AGENT" = true ]; then
	if [ -z "${SSH_AUTH_SOCK:-}" ]; then
		die "SSH_AUTH_SOCK is not set; start an agent and connect with ssh -A"
	fi
	if ! ssh-add -l >/dev/null 2>&1; then
		die "no local SSH identities are available to forward; run ssh-add before syncing"
	fi
fi

remote_script() {
	cat <<'REMOTE'
set -eu

remote_root=$1
branch=$2
root_origin=$3
submodule_mode=$4
fetch=$5
dry_run=$6
status_only=$7
check_agent=$8
all_submodules=$9
shift 9
requested_submodules="$*"
warnings=0

warn() {
	warnings=$((warnings + 1))
	printf 'WARN %s\n' "$*" >&2
}

info() {
	printf 'INFO %s\n' "$*"
}

quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

run() {
	if [ "$dry_run" = true ]; then
		printf '+'
		for arg do
			printf ' %s' "$(quote "$arg")"
		done
		printf '\n'
	else
		"$@"
	fi
}

git_clean_status() {
	repo=$1
	mode=$2
	case "$mode" in
		root) git -C "$repo" status --porcelain --ignore-submodules=all ;;
		*) git -C "$repo" status --porcelain ;;
	esac
}

is_clean() {
	repo=$1
	mode=$2
	test -z "$(git_clean_status "$repo" "$mode")"
}

print_dirty() {
	repo=$1
	mode=$2
	git_clean_status "$repo" "$mode" | sed -n '1,80p' >&2
}

normalize_origin() {
	repo=$1
	label=$2
	expected=$3
	if [ "$status_only" = true ]; then
		current=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
		if [ "$current" != "$expected" ]; then
			warn "$label origin differs current=$current expected=$expected"
		fi
		return 0
	fi

	current=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
	if [ -z "$current" ]; then
		run git -C "$repo" remote add origin "$expected"
		info "$label origin added url=$expected"
	elif [ "$current" != "$expected" ]; then
		run git -C "$repo" remote set-url origin "$expected"
		info "$label origin normalized old=$current new=$expected"
	fi
}

fetch_branch() {
	repo=$1
	label=$2
	name=$3
	[ "$fetch" = true ] || return 0
	if ! run git -C "$repo" fetch --tags --prune origin "$name"; then
		warn "$label fetch failed branch=$name"
		return 1
	fi
}

select_submodules() {
	if [ "$all_submodules" = true ]; then
		git -C "$remote_root" config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
			awk '{ print $2 }'
	else
		[ -n "$requested_submodules" ] || return 0
		printf '%s\n' $requested_submodules
	fi
}

submodule_key_for_path() {
	path=$1
	git -C "$remote_root" config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
		awk -v want="$path" '$2 == want { key = $1; sub(/^submodule\./, "", key); sub(/\.path$/, "", key); print key; found = 1 } END { exit found ? 0 : 1 }'
}

submodule_url() {
	key=$1
	git -C "$remote_root" config --file .gitmodules --get "submodule.$key.url"
}

submodule_branch() {
	key=$1
	git -C "$remote_root" config --file .gitmodules --get "submodule.$key.branch" 2>/dev/null || printf '%s\n' "$branch"
}

submodule_pin() {
	path=$1
	git -C "$remote_root" ls-tree HEAD "$path" | awk '{ print $3 }'
}

report_repo() {
	repo=$1
	label=$2
	mode=$3
	head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || printf 'uninitialized')
	branch_name=$(git -C "$repo" branch --show-current 2>/dev/null || true)
	[ -n "$branch_name" ] || branch_name=detached
	origin=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
	if is_clean "$repo" "$mode"; then
		clean=true
	else
		clean=false
	fi
	printf 'STATUS path=%s head=%s branch=%s clean=%s origin=%s\n' "$label" "$head" "$branch_name" "$clean" "$origin"
}

update_root() {
	normalize_origin "$remote_root" "." "$root_origin"
	report_repo "$remote_root" "." root
	if ! is_clean "$remote_root" root; then
		warn "root checkout is dirty; skipping root fast-forward"
		print_dirty "$remote_root" root
		return 0
	fi
	if [ "$status_only" = true ]; then
		return 0
	fi
	if ! fetch_branch "$remote_root" "." "$branch"; then
		return 0
	fi
	target=origin/$branch
	if ! git -C "$remote_root" rev-parse --verify --quiet "$target^{commit}" >/dev/null; then
		warn "root target is missing: $target"
		return 0
	fi
	if ! git -C "$remote_root" merge-base --is-ancestor HEAD "$target"; then
		warn "root checkout is not a fast-forward ancestor of $target; skipping root update"
		return 0
	fi
	if git -C "$remote_root" show-ref --verify --quiet "refs/heads/$branch"; then
		run git -C "$remote_root" checkout --quiet "$branch"
	else
		run git -C "$remote_root" checkout --quiet -b "$branch" "$target"
	fi
	run git -C "$remote_root" merge --quiet --ff-only "$target"
}

ensure_submodule_initialized() {
	path=$1
	if [ -d "$remote_root/$path/.git" ] || [ -f "$remote_root/$path/.git" ]; then
		return 0
	fi
	if [ "$status_only" = true ]; then
		warn "$path is not initialized"
		return 1
	fi
	run git -C "$remote_root" submodule update --init -- "$path"
}

update_submodule() {
	path=$1
	if ! key=$(submodule_key_for_path "$path"); then
		warn "$path is not declared in .gitmodules; skipping"
		return 0
	fi
	expected_url=$(submodule_url "$key")
	expected_branch=$(submodule_branch "$key")
	pin=$(submodule_pin "$path")

	if ! ensure_submodule_initialized "$path"; then
		return 0
	fi

	repo=$remote_root/$path
	normalize_origin "$repo" "$path" "$expected_url"
	report_repo "$repo" "$path" submodule
	if ! is_clean "$repo" submodule; then
		warn "$path is dirty; skipping submodule update"
		print_dirty "$repo" submodule
		return 0
	fi
	if [ "$status_only" = true ]; then
		return 0
	fi

	if [ "$submodule_mode" = pins ]; then
		if [ -n "$pin" ] && ! git -C "$repo" merge-base --is-ancestor HEAD "$pin"; then
			warn "$path HEAD is not an ancestor of pinned commit $pin; skipping to preserve local commits"
			return 0
		fi
		run git -C "$remote_root" submodule update --init --recursive -- "$path" || warn "$path pinned update failed"
	else
		if ! fetch_branch "$repo" "$path" "$expected_branch"; then
			return 0
		fi
		target=origin/$expected_branch
		if ! git -C "$repo" rev-parse --verify --quiet "$target^{commit}" >/dev/null; then
			warn "$path target is missing: $target"
			return 0
		fi
		if ! git -C "$repo" merge-base --is-ancestor HEAD "$target"; then
			warn "$path is not a fast-forward ancestor of $target; skipping"
			return 0
		fi
		if git -C "$repo" show-ref --verify --quiet "refs/heads/$expected_branch"; then
			run git -C "$repo" checkout --quiet "$expected_branch"
		else
			run git -C "$repo" checkout --quiet -b "$expected_branch" "$target"
		fi
		run git -C "$repo" merge --quiet --ff-only "$target" || warn "$path remote update failed"
	fi

	if [ -d "$repo/.git" ] || [ -f "$repo/.git" ]; then
		normalize_origin "$repo" "$path" "$expected_url"
		report_repo "$repo" "$path" submodule
	fi
}

command -v git >/dev/null 2>&1 || { printf 'missing git on remote host\n' >&2; exit 10; }
if [ "$check_agent" = true ]; then
	if [ -z "${SSH_AUTH_SOCK:-}" ]; then
		printf 'missing forwarded SSH_AUTH_SOCK on remote host; connect with ssh -A\n' >&2
		exit 11
	fi
	if ! ssh-add -l >/dev/null 2>&1; then
		printf 'remote host cannot see forwarded SSH identities; connect with ssh -A and verify ssh-add -l\n' >&2
		exit 12
	fi
	info "ssh-agent forwarding ok"
fi
if [ ! -d "$remote_root/.git" ] && [ ! -f "$remote_root/.git" ]; then
	printf 'not a git checkout on remote host: %s\n' "$remote_root" >&2
	exit 13
fi

cd "$remote_root"
info "remote root=$remote_root branch=$branch submodule_mode=$submodule_mode fetch=$fetch status=$status_only dry_run=$dry_run"
update_root

if [ -f "$remote_root/.gitmodules" ]; then
	if [ "$status_only" != true ]; then
		run git -C "$remote_root" submodule sync --recursive
	fi
	for path in $(select_submodules); do
		update_submodule "$path"
	done
else
	warn ".gitmodules not found after root update; skipping submodules"
fi

if [ "$warnings" -gt 0 ]; then
	printf 'sync-remote-environment: completed with %s warning(s)\n' "$warnings" >&2
	exit 1
fi
printf 'sync-remote-environment: completed without warnings\n'
REMOTE
}

set -- "$REMOTE_ROOT" "$BRANCH" "$ROOT_ORIGIN" "$SUBMODULE_MODE" "$FETCH" "$DRY_RUN" "$STATUS" "$CHECK_AGENT" "$ALL_SUBMODULES" $SUBMODULES
ssh -A -o BatchMode=yes -o ConnectTimeout=10 "$SSH_TARGET" sh -s -- "$@" <<REMOTE_SCRIPT
$(remote_script)
REMOTE_SCRIPT
