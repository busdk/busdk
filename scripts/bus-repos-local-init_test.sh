#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
script="$repo_root/scripts/bus-repos-local-init.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/bus-repos-local-init.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
	printf 'bus-repos-local-init test: %s\n' "$*" >&2
	exit 1
}

expect_line() {
	file=$1
	line=$2
	grep -F -x "$line" "$file" >/dev/null || fail "missing line $line"
}

init_repo() {
	path=$1
	branch=$2
	git init -q -b "$branch" "$path"
	git -C "$path" config user.email repos-test@example.invalid
	git -C "$path" config user.name 'Repos Test'
	printf '%s\n' "$branch" >"$path/README.md"
	git -C "$path" add README.md
	git -C "$path" commit -q -m initial
}

run_init() {
	config=$1
	storage=$2
	shift 2
	BUS_SERVICES_STACK_DIR="$tmp/stack" \
	BUS_REPOS_CONFIG="$config" \
	BUS_REPOS_STORAGE_ROOT="$storage" \
	BUS_WORKERS_DIRECT_REPO_ROOT="$product_repo" \
	BUS_WORKERS_DIRECT_WORKER_IDENTITY_REPO="$identity_repo" \
	"$@" \
	sh "$script"
}

mkdir -p "$tmp/stack"
mkdir -p "$tmp/stack/.bus/worker"
cat >"$tmp/stack/.bus/worker/templates.json" <<'EOF'
{
  "templates": [
    {"id":"claude-fable-5","identity_repo_ref":"repos://workers/claude-fable-5"},
    {"id":"codex-55-high","identity_repo_ref":"repos://workers/codex-55-high"},
    {"id":"duplicate","identity_repo_ref":"repos://workers/codex-55-high"}
  ]
}
EOF
product_repo="$tmp/product"
identity_repo="$tmp/identity"
init_repo "$product_repo" 'product/release'
init_repo "$identity_repo" 'identity/bootstrap'

catalog="$tmp/catalog.yml"
run_init "$catalog" "$tmp/storage" env
expect_line "$catalog" "  - id: busdk/busdk"
expect_line "$catalog" "    legacyIDs:"
expect_line "$catalog" "      - product"
expect_line "$catalog" "    name: 'busdk/busdk'"
expect_line "$catalog" "    path: '$tmp/storage/product.git'"
if grep -F -x '  - id: product' "$catalog" >/dev/null; then
	fail 'legacy product id was exposed as a public catalog identity'
fi
expect_line "$catalog" "    defaultBranch: 'product/release'"
expect_line "$catalog" "    defaultBranch: 'identity/bootstrap'"
expect_line "$catalog" "  - id: workers/claude-fable-5"
expect_line "$catalog" "  - id: workers/codex-55-high"
if [ "$(grep -F -c '  - id: workers/codex-55-high' "$catalog")" -ne 1 ]; then
	fail 'duplicate template identity refs were not deduplicated'
fi

legacy_storage="$tmp/legacy-storage"
mkdir -p "$legacy_storage"
git clone --bare "$product_repo" "$legacy_storage/product.git" >/dev/null
legacy_worktree="$tmp/preserved-worktree"
git --git-dir="$legacy_storage/product.git" worktree add -q -b preserved/worktree "$legacy_worktree" product/release
legacy_head=$(git -C "$legacy_worktree" rev-parse HEAD)
legacy_catalog="$tmp/legacy-catalog.yml"
cat >"$legacy_catalog" <<EOF
groups:
  - id: local
    name: Local
repos:
  - id: product
    group: local
    name: product
    defaultBranch: 'product/release'
    path: '$legacy_storage/product.git'
    remotes:
      - name: origin
        url: '$product_repo'
EOF
git --git-dir="$legacy_storage/product.git" worktree list --porcelain >"$tmp/worktrees.before"
git --git-dir="$legacy_storage/product.git" for-each-ref --format='%(refname) %(objectname)' >"$tmp/refs.before"

run_init "$legacy_catalog" "$legacy_storage" env
expect_line "$legacy_catalog" "  - id: busdk/busdk"
expect_line "$legacy_catalog" "    legacyIDs:"
expect_line "$legacy_catalog" "      - product"
expect_line "$legacy_catalog" "    name: 'busdk/busdk'"
expect_line "$legacy_catalog" "    path: '$legacy_storage/product.git'"
if grep -F -x '  - id: product' "$legacy_catalog" >/dev/null; then
	fail 'migrated catalog still exposed the legacy product identity'
fi
git --git-dir="$legacy_storage/product.git" worktree list --porcelain >"$tmp/worktrees.after"
git --git-dir="$legacy_storage/product.git" for-each-ref --format='%(refname) %(objectname)' >"$tmp/refs.after"
cmp "$tmp/worktrees.before" "$tmp/worktrees.after" >/dev/null || fail 'catalog migration changed the managed worktree inventory'
cmp "$tmp/refs.before" "$tmp/refs.after" >/dev/null || fail 'catalog migration changed repository refs'
if [ "$(git -C "$legacy_worktree" rev-parse HEAD)" != "$legacy_head" ]; then
	fail 'catalog migration changed the preserved worktree HEAD'
fi
cp "$legacy_catalog" "$tmp/legacy-catalog.once.yml"
run_init "$legacy_catalog" "$legacy_storage" env
cmp "$tmp/legacy-catalog.once.yml" "$legacy_catalog" >/dev/null || fail 'canonical catalog initialization was not idempotent'

explicit_catalog="$tmp/explicit.yml"
run_init "$explicit_catalog" "$tmp/explicit-storage" env \
	BUS_WORKERS_DIRECT_BASE_REF='refs/heads/product/release' \
	BUS_WORKERS_DIRECT_WORKER_IDENTITY_BASE_REF='refs/heads/identity/bootstrap'
expect_line "$explicit_catalog" "    defaultBranch: 'refs/heads/product/release'"
expect_line "$explicit_catalog" "    defaultBranch: 'refs/heads/identity/bootstrap'"

git -C "$product_repo" checkout -q --detach
if run_init "$tmp/detached.yml" "$tmp/detached-storage" env >"$tmp/detached.out" 2>&1; then
	fail 'detached product HEAD unexpectedly succeeded'
fi
expect_line "$tmp/detached.out" 'bus repos init: product source HEAD is detached; configured base ref HEAD requires a symbolic local branch'

git -C "$product_repo" symbolic-ref HEAD refs/tags/not-a-branch
if run_init "$tmp/non-branch.yml" "$tmp/non-branch-storage" env >"$tmp/non-branch.out" 2>&1; then
	fail 'non-branch product HEAD unexpectedly succeeded'
fi
expect_line "$tmp/non-branch.out" 'bus repos init: product source HEAD is not a local branch: refs/tags/not-a-branch'
