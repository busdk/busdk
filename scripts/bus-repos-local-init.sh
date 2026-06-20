#!/bin/sh
set -eu

config_path=${BUS_REPOS_CONFIG:-.bus/services/repos/catalog.yml}
storage_root=${BUS_REPOS_STORAGE_ROOT:-.bus/services/repos/storage}
product_repo=${BUS_WORKERS_DIRECT_REPO_ROOT:-${BUS_SERVICES_STACK_DIR:-.}}
identity_repo=${BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO:-"$product_repo/agents/worker"}
product_base=${BUS_WORKERS_DIRECT_BASE_REF:-HEAD}
identity_base=${BUS_WORKERS_DIRECT_WORKER_IDENTITY_BASE_REF:-HEAD}
stack_dir=$(cd "${BUS_SERVICES_STACK_DIR:-.}" && pwd -P)

abs_path() {
  case $1 in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$stack_dir" "$1" ;;
  esac
}

config_path=$(abs_path "$config_path")
storage_root=$(abs_path "$storage_root")
product_repo=$(abs_path "$product_repo")
identity_repo=$(abs_path "$identity_repo")

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
} >"$tmp"

mv "$tmp" "$config_path"
trap - EXIT
