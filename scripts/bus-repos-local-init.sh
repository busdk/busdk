#!/bin/sh
set -eu

config_path=${BUS_REPOS_CONFIG:-.bus/services/repos/catalog.yml}
storage_root=${BUS_REPOS_STORAGE_ROOT:-.bus/services/repos/storage}
product_repo=${BUS_WORKERS_DIRECT_REPO_ROOT:-${BUS_SERVICES_STACK_DIR:-.}}
identity_repo=${BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO:-"$product_repo/agents/worker"}
product_base=${BUS_WORKERS_DIRECT_BASE_REF:-HEAD}
identity_base=${BUS_WORKERS_DIRECT_WORKER_IDENTITY_BASE_REF:-HEAD}
stack_dir=$(cd "${BUS_SERVICES_STACK_DIR:-.}" && pwd -P)
template_catalog=${BUS_WORKER_TEMPLATES_FILE:-"$stack_dir/.bus/worker/templates.json"}
if [ -n "${BUS_SERVICES_BUS_DIR:-}" ]; then
  root_dir=$(cd "$(dirname "$BUS_SERVICES_BUS_DIR")" && pwd -P)
else
  root_dir=$stack_dir
fi

abs_path() {
  case $1 in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$root_dir" "$1" ;;
  esac
}

config_path=$(abs_path "$config_path")
storage_root=$(abs_path "$storage_root")
product_repo=$(abs_path "$product_repo")
identity_repo=$(abs_path "$identity_repo")
template_catalog=$(abs_path "$template_catalog")

yaml_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

catalog_repo_id_count() {
	catalog=$1
	repo_id=$2
	awk -v expected="  - id: $repo_id" '$0 == expected { count++ } END { print count + 0 }' "$catalog"
}

migrate_legacy_product_catalog() {
	catalog_path=$1
	canonical_count=$(catalog_repo_id_count "$catalog_path" busdk/busdk)
	legacy_count=$(catalog_repo_id_count "$catalog_path" product)

	if [ "$canonical_count" -gt 1 ] || [ "$legacy_count" -gt 1 ]; then
		printf 'bus repos init: catalog has duplicate BusDK repository identities: %s\n' "$catalog_path" >&2
		exit 1
	fi
	if [ "$canonical_count" -eq 1 ]; then
		if [ "$legacy_count" -eq 1 ]; then
			printf 'bus repos init: catalog exposes both busdk/busdk and legacy product repository identities: %s\n' "$catalog_path" >&2
			exit 1
		fi
		return 0
  fi
  if [ "$legacy_count" -eq 0 ]; then
    return 0
  fi

	tmp=$(mktemp "$(dirname "$catalog_path")/.catalog.yml.tmp.XXXXXX")
  awk -v canonical_name="'busdk/busdk'" '
    $0 == "  - id: product" {
      print "  - id: busdk/busdk"
      print "    legacyIDs:"
      print "      - product"
      in_legacy_product = 1
      next
    }
    in_legacy_product && $0 ~ /^  - id: / {
      in_legacy_product = 0
    }
    in_legacy_product && ($0 == "    name: product" || $0 == "    name: '\''product'\''" || $0 == "    name: \"product\"") {
      print "    name: " canonical_name
      next
    }
    { print }
	' "$catalog_path" >"$tmp"
	mv "$tmp" "$catalog_path"
}

fail() {
	printf 'bus repos init: %s\n' "$*" >&2
	exit 1
}

yaml_unquote() {
	value=$1
	case $value in
		\'*\')
			value=${value#\'}
			value=${value%\'}
			printf '%s' "$value" | sed "s/''/'/g"
			;;
		\"*\")
			value=${value#\"}
			value=${value%\"}
			printf '%s' "$value"
			;;
		*) printf '%s' "$value" ;;
	esac
}

catalog_repo_ids() {
	awk '/^  - id: / { sub(/^  - id: /, ""); print }' "$1"
}

catalog_repo_field() {
	catalog_path=$1
	repo_id=$2
	field=$3
	awk -v expected="  - id: $repo_id" -v prefix="    $field: " '
		$0 == expected { in_repo = 1; next }
		in_repo && /^  - id: / { exit }
		in_repo && index($0, prefix) == 1 {
			print substr($0, length(prefix) + 1)
			found++
		}
		END { if (found != 1) exit 2 }
	' "$catalog_path"
}

catalog_remote_count() {
	catalog_path=$1
	repo_id=$2
	remote_name=$3
	awk -v expected="  - id: $repo_id" -v remote="      - name: $remote_name" '
		$0 == expected { in_repo = 1; next }
		in_repo && /^  - id: / { in_repo = 0 }
		in_repo && $0 == "    remotes:" { in_remotes = 1; next }
		in_repo && in_remotes && /^    [^ ]/ { in_remotes = 0 }
		in_repo && in_remotes && $0 == remote { count++ }
		END { print count + 0 }
	' "$catalog_path"
}

catalog_remote_url() {
	catalog_path=$1
	repo_id=$2
	remote_name=$3
	awk -v expected="  - id: $repo_id" -v remote="      - name: $remote_name" '
		$0 == expected { in_repo = 1; next }
		in_repo && /^  - id: / { in_repo = 0 }
		in_repo && $0 == "    remotes:" { in_remotes = 1; next }
		in_repo && in_remotes && /^    [^ ]/ { in_remotes = 0 }
		in_repo && in_remotes && $0 == remote { want_url = 1; next }
		want_url && /^        url: / {
			print substr($0, length("        url: ") + 1)
			found++
			want_url = 0
		}
		END { if (found != 1) exit 2 }
	' "$catalog_path"
}

is_external_url() {
	case $1 in
		file://*|/*|./*|../*) return 1 ;;
		*://*|*@*:*) return 0 ;;
		*) return 1 ;;
	esac
}

source_external_url() {
	repo=$1
	if url=$(git -C "$repo" config --get remote.origin.url 2>/dev/null); then
		if [ -n "$url" ] && [ "$url" != "$repo" ] && is_external_url "$url"; then
			printf '%s' "$url"
		fi
	fi
}

merge_external_url() {
	label=$1
	current=$2
	candidate=$3
	if [ -n "$current" ] && [ -n "$candidate" ] && [ "$current" != "$candidate" ]; then
		fail "$label explicit-sync remote mismatch: $current != $candidate"
	fi
	if [ -n "$current" ]; then
		printf '%s' "$current"
	else
		printf '%s' "$candidate"
	fi
}

catalog_external_url() {
	catalog_path=$1
	repo_id=$2
	local_source=$3
	known_external=$4
	origin_count=$(catalog_remote_count "$catalog_path" "$repo_id" origin)
	github_count=$(catalog_remote_count "$catalog_path" "$repo_id" github)
	if [ "$origin_count" -ne 1 ]; then
		if [ "$origin_count" -gt 1 ]; then
			fail "catalog has duplicate origin remotes for $repo_id: $catalog_path"
		fi
		fail "catalog has no automatic origin remote for $repo_id: $catalog_path"
	fi
	if [ "$github_count" -gt 1 ]; then
		fail "catalog has duplicate github explicit-sync remotes for $repo_id: $catalog_path"
	fi
	origin_raw=$(catalog_remote_url "$catalog_path" "$repo_id" origin) || fail "catalog origin remote is malformed for $repo_id: $catalog_path"
	origin_url=$(yaml_unquote "$origin_raw")
	if [ "$origin_url" != "$local_source" ]; then
		if ! is_external_url "$origin_url"; then
			fail "catalog automatic origin mismatch for $repo_id: $origin_url != $local_source"
		fi
		known_external=$(merge_external_url "$repo_id catalog" "$known_external" "$origin_url")
	fi
	if [ "$github_count" -eq 1 ]; then
		github_raw=$(catalog_remote_url "$catalog_path" "$repo_id" github) || fail "catalog github remote is malformed for $repo_id: $catalog_path"
		github_url=$(yaml_unquote "$github_raw")
		if ! is_external_url "$github_url"; then
			fail "catalog github explicit-sync remote is not external for $repo_id: $github_url"
		fi
		known_external=$(merge_external_url "$repo_id catalog" "$known_external" "$github_url")
	fi
	printf '%s' "$known_external"
}

rewrite_catalog_remotes() {
	catalog_path=$1
	repo_id=$2
	local_source=$3
	external_url=$4
	local_quoted=$(yaml_quote "$local_source")
	external_quoted=$(yaml_quote "$external_url")
	tmp=$(mktemp "$(dirname "$catalog_path")/.catalog.yml.tmp.XXXXXX")
	awk -v expected="  - id: $repo_id" -v local_url="$local_quoted" -v external_url="$external_quoted" -v add_external="$([ -n "$external_url" ] && printf 1 || printf 0)" '
		function add_github() {
			if (add_external == 1 && !seen_github) {
				print "      - name: github"
				print "        url: " external_url
				seen_github = 1
			}
		}
		$0 == expected { in_repo = 1; print; next }
		in_repo && /^  - id: / {
			if (in_remotes) add_github()
			in_repo = 0
			in_remotes = 0
			current_remote = ""
			print
			next
		}
		in_repo && $0 == "    remotes:" {
			in_remotes = 1
			seen_github = 0
			print
			next
		}
		in_repo && in_remotes && /^    [^ ]/ {
			add_github()
			in_remotes = 0
			current_remote = ""
			print
			next
		}
		in_repo && in_remotes && $0 == "      - name: origin" {
			current_remote = "origin"
			print
			next
		}
		in_repo && in_remotes && $0 == "      - name: github" {
			current_remote = "github"
			seen_github = 1
			print
			next
		}
		in_repo && in_remotes && current_remote == "origin" && /^        url: / {
			print "        url: " local_url
			current_remote = ""
			next
		}
		in_repo && in_remotes && current_remote == "github" && /^        url: / {
			print "        url: " external_url
			current_remote = ""
			next
		}
		{ print }
		END { if (in_repo && in_remotes) add_github() }
	' "$catalog_path" >"$tmp"
	mv "$tmp" "$catalog_path"
}

validate_catalog_repo() {
	catalog_path=$1
	repo_id=$2
	expected_path=$3
	expected_base=$4
	path_raw=$(catalog_repo_field "$catalog_path" "$repo_id" path) || fail "catalog path is missing or duplicated for $repo_id: $catalog_path"
	base_raw=$(catalog_repo_field "$catalog_path" "$repo_id" defaultBranch) || fail "catalog default branch is missing or duplicated for $repo_id: $catalog_path"
	actual_path=$(yaml_unquote "$path_raw")
	actual_base=$(yaml_unquote "$base_raw")
	if [ "$actual_path" != "$expected_path" ]; then
		fail "catalog repository path mismatch for $repo_id: $actual_path != $expected_path"
	fi
	if [ "$actual_base" != "$expected_base" ]; then
		fail "catalog default branch mismatch for $repo_id: $actual_base != $expected_base"
	fi
}

ensure_source_repo() {
  label=$1
  repo=$2
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'bus repos init: %s source is not a Git repository: %s\n' "$label" "$repo" >&2
    exit 1
  fi
}

canonical_source_path() {
	label=$1
	repo=$2
	if [ ! -d "$repo" ]; then
		fail "$label source is not a Git repository: $repo"
	fi
	repo=$(cd "$repo" && pwd -P)
	if ! top=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null); then
		fail "$label source is not a Git repository: $repo"
	fi
	top=$(cd "$top" && pwd -P)
	if [ "$top" != "$repo" ]; then
		fail "$label source repository root mismatch: $top != $repo"
	fi
	printf '%s' "$repo"
}

resolve_base_ref() {
  label=$1
  repo=$2
  base_ref=$3
  if [ "$base_ref" != "HEAD" ]; then
    printf '%s' "$base_ref"
    return 0
  fi

  if head_ref=$(git -C "$repo" symbolic-ref --quiet HEAD 2>/dev/null); then
    :
  else
    status=$?
    if [ "$status" -eq 1 ]; then
      printf 'bus repos init: %s source HEAD is detached; configured base ref HEAD requires a symbolic local branch\n' "$label" >&2
    else
      printf 'bus repos init: cannot resolve %s source HEAD\n' "$label" >&2
    fi
    exit 1
  fi
  case $head_ref in
    refs/heads/*) ;;
    *)
      printf 'bus repos init: %s source HEAD is not a local branch: %s\n' "$label" "$head_ref" >&2
      exit 1
      ;;
  esac
  if ! git -C "$repo" show-ref --verify --quiet "$head_ref"; then
    printf 'bus repos init: %s source HEAD local branch does not exist: %s\n' "$label" "$head_ref" >&2
    exit 1
  fi
  printf '%s' "${head_ref#refs/heads/}"
}

ensure_bare_repo() {
	label=$1
	dest=$2
	source=$3
	if [ ! -f "$dest/HEAD" ]; then
		mkdir -p "$(dirname "$dest")"
		if ! git clone --bare "$source" "$dest" >/dev/null; then
			fail "cannot clone $label accepted local source into managed repository: $source"
		fi
	fi
	if ! bare=$(git -C "$dest" rev-parse --is-bare-repository 2>/dev/null) || [ "$bare" != true ]; then
		fail "$label managed repository is not a Git repository: $dest"
	fi
}

bare_external_url() {
	label=$1
	dest=$2
	local_source=$3
	known_external=$4
	if origin_url=$(git -C "$dest" remote get-url origin 2>/dev/null); then
		if [ "$origin_url" != "$local_source" ]; then
			if ! is_external_url "$origin_url"; then
				fail "$label managed origin mismatch: $origin_url != $local_source"
			fi
			known_external=$(merge_external_url "$label managed repository" "$known_external" "$origin_url")
		fi
	fi
	if github_url=$(git -C "$dest" remote get-url github 2>/dev/null); then
		if ! is_external_url "$github_url"; then
			fail "$label managed github explicit-sync remote is not external: $github_url"
		fi
		known_external=$(merge_external_url "$label managed repository" "$known_external" "$github_url")
	fi
	printf '%s' "$known_external"
}

configure_bare_remotes() {
	label=$1
	dest=$2
	local_source=$3
	external_url=$4
	if git -C "$dest" remote get-url origin >/dev/null 2>&1; then
		git -C "$dest" remote set-url origin "$local_source" || fail "cannot set $label managed local origin: $dest"
	else
		git -C "$dest" remote add origin "$local_source" || fail "cannot add $label managed local origin: $dest"
	fi
	if [ -n "$external_url" ]; then
		if git -C "$dest" remote get-url github >/dev/null 2>&1; then
			git -C "$dest" remote set-url github "$external_url" || fail "cannot set $label explicit-sync remote: $dest"
		else
			git -C "$dest" remote add github "$external_url" || fail "cannot add $label explicit-sync remote: $dest"
		fi
	fi
}

rollback_bares=0
product_config_backup=
identity_config_backup=
lock_dir=
lock_owner_path=
lock_owner_id=
lock_owner_uid=

lock_is_owned_by_current_process() {
	[ -n "$lock_owner_path" ] && [ -f "$lock_owner_path" ] || return 1
	owner_id=$(cat "$lock_owner_path" 2>/dev/null) || return 1
	[ "$owner_id" = "$lock_owner_id" ]
}

reclaim_stale_lock() {
	[ -n "$lock_owner_path" ] && [ -f "$lock_owner_path" ] || return 1
	owner_id=$(cat "$lock_owner_path" 2>/dev/null) || return 1
	case $owner_id in
		*:*:*) return 1 ;;
	esac
	owner_pid=${owner_id%%:*}
	owner_uid=${owner_id#*:}
	case $owner_pid in
		''|*[!0-9]*) return 1 ;;
	esac
	case $owner_uid in
		''|*[!0-9]*) return 1 ;;
	esac
	[ "$owner_uid" = "$lock_owner_uid" ] || return 1
	if kill -0 "$owner_pid" 2>/dev/null; then
		return 1
	fi
	owner_check=$(cat "$lock_owner_path" 2>/dev/null) || return 1
	[ "$owner_check" = "$owner_id" ] || return 1
	rm -f "$lock_owner_path" || return 1
	rmdir "$lock_dir" 2>/dev/null
}

cleanup() {
	if [ "$rollback_bares" -eq 1 ]; then
		[ -z "$product_config_backup" ] || cp "$product_config_backup" "$product_path/config" || :
		[ -z "$identity_config_backup" ] || cp "$identity_config_backup" "$identity_path/config" || :
	fi
	[ -z "$product_config_backup" ] || rm -f "$product_config_backup"
	[ -z "$identity_config_backup" ] || rm -f "$identity_config_backup"
	if lock_is_owned_by_current_process; then
		rm -f "$lock_owner_path" || :
		rmdir "$lock_dir" 2>/dev/null || :
	fi
}

mkdir -p "$(dirname "$config_path")"
lock_dir="${config_path}.lock"
lock_owner_path="$lock_dir/owner"
lock_owner_uid=$(id -u) || fail "cannot determine migration lock owner"
lock_owner_id="$$:$lock_owner_uid"
lock_timeout=${BUS_REPOS_LOCAL_INIT_LOCK_TIMEOUT_SECONDS:-30}
case $lock_timeout in
	''|*[!0-9]*) fail "migration lock timeout must be a positive number of seconds: $lock_timeout" ;;
esac
if [ "$lock_timeout" -eq 0 ]; then
	fail "migration lock timeout must be a positive number of seconds: $lock_timeout"
fi
trap cleanup EXIT HUP INT TERM
lock_waited=0
while ! mkdir "$lock_dir" 2>/dev/null; do
	if reclaim_stale_lock; then
		continue
	fi
	if [ "$lock_waited" -ge "$lock_timeout" ]; then
		fail "timed out waiting for migration lock: $lock_dir"
	fi
	lock_waited=$((lock_waited + 1))
	sleep 1
done
if ! (umask 077; printf '%s\n' "$lock_owner_id" >"$lock_owner_path"); then
	rmdir "$lock_dir" 2>/dev/null || :
	fail "cannot record migration lock owner: $lock_dir"
fi

product_repo=$(canonical_source_path product "$product_repo")
identity_repo=$(canonical_source_path worker-identity "$identity_repo")

ensure_source_repo product "$product_repo"
ensure_source_repo worker-identity "$identity_repo"

product_base=$(resolve_base_ref product "$product_repo" "$product_base")
identity_base=$(resolve_base_ref worker-identity "$identity_repo" "$identity_base")

product_branch=${product_base#refs/heads/}
identity_branch=${identity_base#refs/heads/}
if ! git -C "$product_repo" show-ref --verify --quiet "refs/heads/$product_branch"; then
	fail "product source base ref does not exist: $product_base"
fi
if ! git -C "$identity_repo" show-ref --verify --quiet "refs/heads/$identity_branch"; then
	fail "worker-identity source base ref does not exist: $identity_base"
fi

product_path="$storage_root/product.git"
identity_path="$storage_root/worker-identity.git"
product_external=$(source_external_url "$product_repo")
identity_external=$(source_external_url "$identity_repo")

if [ -f "$config_path" ]; then
	catalog_work=$(mktemp "$(dirname "$config_path")/.catalog.yml.migrate.XXXXXX")
	cp "$config_path" "$catalog_work"
	migrate_legacy_product_catalog "$catalog_work"
	if [ "$(catalog_repo_id_count "$catalog_work" busdk/busdk)" -ne 1 ]; then
		fail "catalog is missing canonical BusDK repository identity: $config_path"
	fi
	validate_catalog_repo "$catalog_work" busdk/busdk "$product_path" "$product_base"
	product_external=$(catalog_external_url "$catalog_work" busdk/busdk "$product_repo" "$product_external")
	for repo_id in $(catalog_repo_ids "$catalog_work"); do
		case $repo_id in
			worker-identity|workers/*)
				validate_catalog_repo "$catalog_work" "$repo_id" "$identity_path" "$identity_base"
				identity_external=$(catalog_external_url "$catalog_work" "$repo_id" "$identity_repo" "$identity_external")
				;;
		esac
	done

	ensure_bare_repo product "$product_path" "$product_repo"
	ensure_bare_repo worker-identity "$identity_path" "$identity_repo"
	product_config_backup=$(mktemp "$product_path/.config.rollback.XXXXXX")
	identity_config_backup=$(mktemp "$identity_path/.config.rollback.XXXXXX")
	cp "$product_path/config" "$product_config_backup"
	cp "$identity_path/config" "$identity_config_backup"
	rollback_bares=1
	product_external=$(bare_external_url product "$product_path" "$product_repo" "$product_external")
	identity_external=$(bare_external_url worker-identity "$identity_path" "$identity_repo" "$identity_external")
	configure_bare_remotes product "$product_path" "$product_repo" "$product_external"
	configure_bare_remotes worker-identity "$identity_path" "$identity_repo" "$identity_external"
	if [ "${BUS_REPOS_LOCAL_INIT_TEST_FAIL_AFTER_BARE_REMOTES:-}" = 1 ]; then
		fail "injected failure after managed bare remote migration"
	fi
	rewrite_catalog_remotes "$catalog_work" busdk/busdk "$product_repo" "$product_external"
	for repo_id in $(catalog_repo_ids "$catalog_work"); do
		case $repo_id in
			worker-identity|workers/*) rewrite_catalog_remotes "$catalog_work" "$repo_id" "$identity_repo" "$identity_external" ;;
		esac
	done
	mv "$catalog_work" "$config_path"
	rollback_bares=0
	exit 0
fi

ensure_bare_repo product "$product_path" "$product_repo"
ensure_bare_repo worker-identity "$identity_path" "$identity_repo"
product_external=$(bare_external_url product "$product_path" "$product_repo" "$product_external")
identity_external=$(bare_external_url worker-identity "$identity_path" "$identity_repo" "$identity_external")
configure_bare_remotes product "$product_path" "$product_repo" "$product_external"
configure_bare_remotes worker-identity "$identity_path" "$identity_repo" "$identity_external"

tmp=$(mktemp "$(dirname "$config_path")/.catalog.yml.tmp.XXXXXX")

{
  printf 'groups:\n'
  printf '  - id: local\n'
  printf '    name: Local\n'
  printf 'repos:\n'
  printf '  - id: busdk/busdk\n'
  printf '    legacyIDs:\n'
  printf '      - product\n'
  printf '    group: local\n'
  printf '    name: %s\n' "$(yaml_quote 'busdk/busdk')"
  printf '    defaultBranch: %s\n' "$(yaml_quote "$product_base")"
  printf '    path: %s\n' "$(yaml_quote "$product_path")"
	printf '    remotes:\n'
	printf '      - name: origin\n'
	printf '        url: %s\n' "$(yaml_quote "$product_repo")"
	if [ -n "$product_external" ]; then
		printf '      - name: github\n'
		printf '        url: %s\n' "$(yaml_quote "$product_external")"
	fi
  printf '  - id: worker-identity\n'
  printf '    group: local\n'
  printf '    name: worker-identity\n'
  printf '    defaultBranch: %s\n' "$(yaml_quote "$identity_base")"
  printf '    path: %s\n' "$(yaml_quote "$identity_path")"
	printf '    remotes:\n'
	printf '      - name: origin\n'
	printf '        url: %s\n' "$(yaml_quote "$identity_repo")"
	if [ -n "$identity_external" ]; then
		printf '      - name: github\n'
		printf '        url: %s\n' "$(yaml_quote "$identity_external")"
	fi
  if [ -f "$template_catalog" ]; then
    sed -n 's/.*"identity_repo_ref":[[:space:]]*"repos:\/\/\([^"]*\)".*/\1/p' "$template_catalog" |
      LC_ALL=C sort -u |
      while IFS= read -r repo_id; do
        [ -n "$repo_id" ] || continue
        printf '  - id: %s\n' "$repo_id"
        printf '    group: local\n'
        printf '    name: %s\n' "$(yaml_quote "$repo_id")"
        printf '    defaultBranch: %s\n' "$(yaml_quote "$identity_base")"
        printf '    path: %s\n' "$(yaml_quote "$identity_path")"
		printf '    remotes:\n'
		printf '      - name: origin\n'
		printf '        url: %s\n' "$(yaml_quote "$identity_repo")"
		if [ -n "$identity_external" ]; then
			printf '      - name: github\n'
			printf '        url: %s\n' "$(yaml_quote "$identity_external")"
		fi
	  done
  fi
} >"$tmp"

mv "$tmp" "$config_path"
