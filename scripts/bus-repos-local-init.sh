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

if [ -f "$config_path" ]; then
  exit 0
fi

yaml_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

remote_url() {
  repo=$1
  if url=$(git -C "$repo" config --get remote.origin.url 2>/dev/null); then
    if [ -n "$url" ]; then
      printf '%s' "$url"
      return 0
    fi
  fi
  printf '%s' "$repo"
}

ensure_source_repo() {
  label=$1
  repo=$2
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'bus repos init: %s source is not a Git repository: %s\n' "$label" "$repo" >&2
    exit 1
  fi
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
  id=$1
  source=$2
  dest="$storage_root/$id.git"
  if [ ! -f "$dest/HEAD" ]; then
    mkdir -p "$(dirname "$dest")"
    git clone --bare "$source" "$dest" >/dev/null
  fi
  printf '%s' "$dest"
}

ensure_source_repo product "$product_repo"
ensure_source_repo worker-identity "$identity_repo"

product_base=$(resolve_base_ref product "$product_repo" "$product_base")
identity_base=$(resolve_base_ref worker-identity "$identity_repo" "$identity_base")

product_path=$(ensure_bare_repo product "$product_repo")
identity_path=$(ensure_bare_repo worker-identity "$identity_repo")
product_remote=$(remote_url "$product_repo")
identity_remote=$(remote_url "$identity_repo")

mkdir -p "$(dirname "$config_path")"
tmp=$(mktemp "$(dirname "$config_path")/.catalog.yml.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

{
  printf 'groups:\n'
  printf '  - id: local\n'
  printf '    name: Local\n'
  printf 'repos:\n'
  printf '  - id: product\n'
  printf '    group: local\n'
  printf '    name: product\n'
  printf '    defaultBranch: %s\n' "$(yaml_quote "$product_base")"
  printf '    path: %s\n' "$(yaml_quote "$product_path")"
  printf '    remotes:\n'
  printf '      - name: origin\n'
  printf '        url: %s\n' "$(yaml_quote "$product_remote")"
  printf '  - id: worker-identity\n'
  printf '    group: local\n'
  printf '    name: worker-identity\n'
  printf '    defaultBranch: %s\n' "$(yaml_quote "$identity_base")"
  printf '    path: %s\n' "$(yaml_quote "$identity_path")"
  printf '    remotes:\n'
  printf '      - name: origin\n'
  printf '        url: %s\n' "$(yaml_quote "$identity_remote")"
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
        printf '        url: %s\n' "$(yaml_quote "$identity_remote")"
      done
  fi
} >"$tmp"

mv "$tmp" "$config_path"
trap - EXIT
