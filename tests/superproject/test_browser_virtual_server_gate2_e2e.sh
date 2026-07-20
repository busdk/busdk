#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TUPLE_FORMAT="bus-engine-os-chromium-vertical-slice-evidence-v1"
QEMU_COMPILED_SOURCE_COMMIT=200ae823bff18b1229b54b0dd7cc1010123bac19
QEMU_COMPILED_JS_SHA256=f02dda0c31ed62b8b6666960dbab0c414b5975e3ddcbd39250a8ed11859d11ac
QEMU_COMPILED_WASM_SHA256=881fb579a02022d61b288543b2ee94ce65e92f36a3bce2cbe209c2707d4f8fba

PLAN_MODE=0
ROLE=""
CASE_ID=""
RESULT_DIR=""
EXPECTED_FAIL_GATE=""
EXPECTED_FAIL_PREDICATE=""
BUS_GATE2_SCENARIO_DIGEST=""
OBSERVED_CLASSIFICATION="not-run"
G4_STARTED=0

ROLE_T50_OWNER=bus_engine_os
ROLE_T50_PARENT=a6c0769842167881027674c9441ec704c573d59e
ROLE_T50_CANDIDATE=88076c6f5141c2f68ae7b191029729efcadb8b7d
ROLE_T50_PARENT_FAIL_GATE=g2-boot
ROLE_T50_PARENT_FAIL_PREDICATE='bus-engine-os login:'
ROLE_T64_OWNER=bus_engine_os
ROLE_T64_PARENT=2b57575a413e6efb00f2ac00fbcc69e63dbc26a3
ROLE_T64_CANDIDATE=692f3930f04abf133179dbf80aea39019a383c0d
ROLE_T64_PARENT_FAIL_GATE=
ROLE_T64_PARENT_FAIL_PREDICATE=
ROLE_T65_OWNER=qemu
ROLE_T65_PARENT=985d809f1c098623cddf4ca67b117bcc5040979c
ROLE_T65_CANDIDATE=07aa925ffacac8a56e1d6dd8a0463c61f62706ea
ROLE_T65_PARENT_FAIL_GATE=g1-qemu-wasm-chardev-emscripten-abi-test
ROLE_T65_PARENT_FAIL_PREDICATE='production source must provide pending_input_token'
ROLE_T154_OWNER=qemu
ROLE_T154_PARENT=985d809f1c098623cddf4ca67b117bcc5040979c
ROLE_T154_CANDIDATE=35ab187f5b853b8d059b9c535b4f95d6e9f0dd07
ROLE_T66_OWNER=bus_engine_os
ROLE_T66_TIP=462d365f5c0a94a2683cec718f8b01c90b4e2ebc
VERIFIED_ROLE_OWNER=""
VERIFIED_ROLE_PARENT=""
VERIFIED_ROLE_CANDIDATE=""
VERIFIED_SELECTED_COMMIT=""
VERIFIED_RELATIONSHIP_RESULT=""
VERIFIED_COMPOSED_BEO_CONTAINS_T64=""
VERIFIED_COMPOSED_BEO_CONTAINS_T66=""
VERIFIED_COMPOSED_QEMU_CONTAINS_T65=""
VERIFIED_COMPOSED_QEMU_CONTAINS_T154=""
FIXED_FAIL_GATE=""
FIXED_FAIL_PREDICATE=""

usage() {
  cat >&2 <<'EOF'
usage:
  test_browser_virtual_server_gate2_e2e.sh --case T50|T64|T65|composed --role parent-fail --result-dir DIR [--expected-fail-gate GATE --expected-fail-predicate TEXT]
  test_browser_virtual_server_gate2_e2e.sh --case T50|T64|T65|composed --role candidate-pass --result-dir DIR
  test_browser_virtual_server_gate2_e2e.sh --plan --case composed --role candidate-pass --result-dir DIR
  test_browser_virtual_server_gate2_e2e.sh --self-test
  test_browser_virtual_server_gate2_e2e.sh --self-test-t65-public-flow

Execution modes require exact BUS_GATE2_* identity fields. The harness owns the
packet G0-G4 argv, role bindings, and parent-failure predicates.
EOF
}

die() {
  printf 'browser-gate2: %s\n' "$*" >&2
  exit 1
}

json_escape() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

mono_ms() {
  python3 -c 'import time; print(time.monotonic_ns()//1000000)'
}

sha256_file() {
  local file=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  die "missing sha256sum/shasum"
}

sha256_text() {
  local text=$1
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$text" | sha256sum | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$text" | shasum -a 256 | awk '{print $1}'
    return
  fi
  die "missing sha256sum/shasum"
}

file_size() {
  local file=$1
  if stat -c '%s' "$file" >/dev/null 2>&1; then
    stat -c '%s' "$file"
    return
  fi
  stat -f '%z' "$file"
}

bundle_identity() {
  python3 - "$1" <<'PY'
import hashlib
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
records = []
size = 0
paths = sorted(root.rglob("*"), key=lambda path: path.relative_to(root).as_posix())
for path in paths:
    mode = path.lstat().st_mode
    relative = path.relative_to(root).as_posix()
    if "\n" in relative:
        raise SystemExit("bundle path contains newline")
    if stat.S_ISDIR(mode):
        continue
    if not stat.S_ISREG(mode):
        raise SystemExit(f"bundle entry is not a regular file: {relative}")
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    size += path.lstat().st_size
    records.append(f"{digest.hexdigest()}  {relative}\n".encode("utf-8"))

identity = hashlib.sha256()
for record in records:
    identity.update(record)
print(f"{size}\t{identity.hexdigest()}")
PY
}

require_var() {
  local name=$1
  if [ -z "${!name+x}" ]; then die "missing required field: $name"; fi
  if [ -z "${!name}" ]; then die "empty required field: $name"; fi
}

require_40hex() {
  local name=$1
  require_var "$name"
  case "${!name}" in *[!0123456789abcdef]*) die "$name must be lowercase 40-hex" ;; esac
  [ "$(printf '%s' "${!name}" | wc -c | awk '{print $1}')" = "40" ] || die "$name must be lowercase 40-hex"
}

require_64hex() {
  local name=$1
  require_var "$name"
  case "${!name}" in *[!0123456789abcdef]*) die "$name must be lowercase 64-hex" ;; esac
  [ "$(printf '%s' "${!name}" | wc -c | awk '{print $1}')" = "64" ] || die "$name must be lowercase 64-hex"
}

require_decimal() {
  local name=$1
  require_var "$name"
  case "${!name}" in *[!0123456789]*) die "$name must be a decimal byte size" ;; esac
}

require_docker_id() {
  local name=$1
  require_var "$name"
  case "${!name}" in
    sha256:????????????????????????????????????????????????????????????????)
      case "${!name#sha256:}" in *[!0123456789abcdef]*) die "$name must be sha256:<64 lowercase hex>" ;; esac
      ;;
    *) die "$name must be sha256:<64 lowercase hex>" ;;
  esac
}

require_path_file() {
  local name=$1
  require_var "$name"
  [ -f "${!name}" ] || die "$name is not a regular file: ${!name}"
}

require_path_dir() {
  local name=$1
  require_var "$name"
  [ -d "${!name}" ] || die "$name is not a directory: ${!name}"
}

require_artifact() {
  local path_name=$1 size_name=$2 sha_name=$3 actual_size actual_sha
  require_path_file "$path_name"
  require_decimal "$size_name"
  require_64hex "$sha_name"
  actual_size=$(file_size "${!path_name}")
  actual_sha=$(sha256_file "${!path_name}")
  [ "$actual_size" = "${!size_name}" ] || die "$size_name mismatch for $path_name: expected ${!size_name}, got $actual_size"
  [ "$actual_sha" = "${!sha_name}" ] || die "$sha_name mismatch for $path_name: expected ${!sha_name}, got $actual_sha"
}

require_bundle() {
  local path_name=$1 size_name=$2 sha_name=$3 identity actual_size actual_sha
  require_path_dir "$path_name"
  require_decimal "$size_name"
  require_64hex "$sha_name"
  identity=$(bundle_identity "${!path_name}") || die "failed to compute bundle identity for $path_name"
  actual_size=${identity%%$'\t'*}
  actual_sha=${identity#*$'\t'}
  [ "$actual_size" = "${!size_name}" ] || die "$size_name mismatch for $path_name: expected ${!size_name}, got $actual_size"
  [ "$actual_sha" = "${!sha_name}" ] || die "$sha_name mismatch for $path_name: expected ${!sha_name}, got $actual_sha"
}

git_head() { git -C "$1" rev-parse HEAD; }

require_git_head() {
  local root_name=$1 commit_name=$2 actual
  require_path_dir "$root_name"
  require_40hex "$commit_name"
  actual=$(git_head "${!root_name}")
  [ "$actual" = "${!commit_name}" ] || die "$commit_name mismatch for $root_name: expected ${!commit_name}, got $actual"
}

require_busdk_gitlink_pin() {
  local path_name=$1 pin_name=$2 mode actual
  require_var "$path_name"
  require_40hex "$pin_name"
  local record type path
  record=$(git -C "$ROOT_DIR" ls-tree "$BUS_GATE2_BUSDK_COMMIT" -- "${!path_name}")
  [ -n "$record" ] || die "$path_name missing from declared BusDK tree: ${!path_name}"
  mode=$(printf '%s\n' "$record" | awk '{print $1}')
  type=$(printf '%s\n' "$record" | awk '{print $2}')
  actual=$(printf '%s\n' "$record" | awk '{print $3}')
  path=$(printf '%s\n' "$record" | sed 's/^[^	]*	//')
  [ "$mode" = "160000" ] || die "$path_name is not a gitlink in declared BusDK tree: ${!path_name}"
  [ "$type" = "commit" ] || die "$path_name is not a commit gitlink in declared BusDK tree: ${!path_name}"
  [ "$actual" = "${!pin_name}" ] || die "$pin_name mismatch for $path_name: expected ${!pin_name}, got $actual"
  [ "$path" = "${!path_name}" ] || die "$path_name path mismatch in declared BusDK tree: expected ${!path_name}, got $path"
}

require_git_root_clean() {
  local root_name=$1
  require_path_dir "$root_name"
  git -C "${!root_name}" rev-parse --show-toplevel >/dev/null
  [ "$(git -C "${!root_name}" rev-parse --show-toplevel)" = "$(cd "${!root_name}" && pwd -P)" ] || die "$root_name must be an exact Git root: ${!root_name}"
  if [ -n "$(git -C "${!root_name}" status --short --untracked-files=no)" ]; then
    die "$root_name has tracked modifications"
  fi
}

ensure_safe_result_dir() {
  local dir=$1
  [ -n "$dir" ] || die "missing --result-dir"
  [ "$dir" != "/" ] || die "refusing root result dir"
  if [ -e "$dir" ]; then
    [ -d "$dir" ] || die "result path exists and is not a directory: $dir"
    if find "$dir" -mindepth 1 -print -quit | grep -q .; then
      die "refusing existing non-empty result directory: $dir"
    fi
  fi
  mkdir -p "$dir"
}

require_script() {
  local path=$1
  [ -f "$path" ] || die "harness-gap: accepted checked-in path is absent: $path"
}

render_argv() {
  local out=$1
  shift
  : >"$out"
  local arg
  for arg in "$@"; do printf '%s\0' "$arg" >>"$out"; done
}

readable_argv() {
  local out=$1
  shift
  : >"$out"
  local arg
  for arg in "$@"; do printf '%s\n' "$arg" >>"$out"; done
}

record_gate_status() {
  local gate=$1 status=$2 started=$3 ended=$4 start_ms=$5 end_ms=$6 out_dir=$7
  local stdout_file="$out_dir/${gate}.stdout"
  local stderr_file="$out_dir/${gate}.stderr"
  local argv_file="$out_dir/${gate}.argv0"
  local stdout_sha stderr_sha duration
  duration=$((end_ms - start_ms))
  stdout_sha=$(sha256_file "$stdout_file")
  stderr_sha=$(sha256_file "$stderr_file")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$gate" "$status" "$started" "$ended" "$duration" "$argv_file" "$stdout_file" "$stdout_sha" "$stderr_file" "$stderr_sha" >>"$RESULT_DIR/status.tsv"
}

run_argv_at() {
  local root=$1 gate=$2 out_dir=$3
  shift 3
  local stdout_file="$out_dir/${gate}.stdout"
  local stderr_file="$out_dir/${gate}.stderr"
  local argv_file="$out_dir/${gate}.argv0"
  local argv_txt="$out_dir/${gate}.argv.txt"
  local started ended start_ms end_ms status
  mkdir -p "$out_dir"
  render_argv "$argv_file" "$@"
  readable_argv "$argv_txt" "$@"
  started=$(now_utc)
  start_ms=$(mono_ms)
  set +e
  (cd "$root" && "$@") >"$stdout_file" 2>"$stderr_file"
  status=$?
  set -e
  end_ms=$(mono_ms)
  ended=$(now_utc)
  record_gate_status "$gate" "$status" "$started" "$ended" "$start_ms" "$end_ms" "$out_dir"
  return "$status"
}

plan_argv_at() {
  local root=$1 gate=$2 out_dir=$3
  shift 3
  local stdout_file="$out_dir/${gate}.stdout"
  local stderr_file="$out_dir/${gate}.stderr"
  local argv_file="$out_dir/${gate}.argv0"
  local argv_txt="$out_dir/${gate}.argv.txt"
  mkdir -p "$out_dir"
  render_argv "$argv_file" "$@"
  readable_argv "$argv_txt" "$@"
  : >"$stdout_file"
  : >"$stderr_file"
  printf '%s\tPLAN\t%s\t%s\t0\t%s\t%s\t%s\t%s\t%s\n' \
    "$gate" "$(now_utc)" "$(now_utc)" "$argv_file" "$stdout_file" "$(sha256_file "$stdout_file")" "$stderr_file" "$(sha256_file "$stderr_file")" >>"$RESULT_DIR/status.tsv"
}

gate_argv_at() {
  if [ "$PLAN_MODE" = "1" ]; then plan_argv_at "$@"; else run_argv_at "$@"; fi
}

owner_root_var() {
  case "$1" in
    bus_engine_os) printf '%s' BUS_GATE2_BUS_ENGINE_OS_ROOT ;;
    qemu) printf '%s' BUS_GATE2_QEMU_ROOT ;;
    *) die "unsupported role owner: $1" ;;
  esac
}

owner_commit_var() {
  case "$1" in
    bus_engine_os) printf '%s' BUS_GATE2_BUS_ENGINE_OS_COMMIT ;;
    qemu) printf '%s' BUS_GATE2_QEMU_COMMIT ;;
    *) die "unsupported role owner: $1" ;;
  esac
}

role_owner() {
  case "$1" in
    T50) printf '%s' "$ROLE_T50_OWNER" ;;
    T64) printf '%s' "$ROLE_T64_OWNER" ;;
    T65) printf '%s' "$ROLE_T65_OWNER" ;;
    T154) printf '%s' "$ROLE_T154_OWNER" ;;
    T66) printf '%s' "$ROLE_T66_OWNER" ;;
    *) die "unknown role spec: $1" ;;
  esac
}

role_parent() {
  case "$1" in
    T50) printf '%s' "$ROLE_T50_PARENT" ;;
    T64) printf '%s' "$ROLE_T64_PARENT" ;;
    T65) printf '%s' "$ROLE_T65_PARENT" ;;
    T154) printf '%s' "$ROLE_T154_PARENT" ;;
    *) die "role has no parent: $1" ;;
  esac
}

role_candidate() {
  case "$1" in
    T50) printf '%s' "$ROLE_T50_CANDIDATE" ;;
    T64) printf '%s' "$ROLE_T64_CANDIDATE" ;;
    T65) printf '%s' "$ROLE_T65_CANDIDATE" ;;
    T154) printf '%s' "$ROLE_T154_CANDIDATE" ;;
    *) die "role has no candidate: $1" ;;
  esac
}

role_parent_fail_gate() {
  case "$1" in
    T50) printf '%s' "$ROLE_T50_PARENT_FAIL_GATE" ;;
    T64) die "T64 parent-fail has no packet-owned package/import-wrapper predicate; later provenance slice must supply an accepted explicit control" ;;
    T65) printf '%s' "$ROLE_T65_PARENT_FAIL_GATE" ;;
    *) die "role has no parent-failure gate: $1" ;;
  esac
}

role_parent_fail_predicate() {
  case "$1" in
    T50) printf '%s' "$ROLE_T50_PARENT_FAIL_PREDICATE" ;;
    T64) die "T64 parent-fail has no packet-owned package/import-wrapper predicate; later provenance slice must supply an accepted explicit control" ;;
    T65) printf '%s' "$ROLE_T65_PARENT_FAIL_PREDICATE" ;;
    *) die "role has no parent-failure predicate: $1" ;;
  esac
}

require_commit_in_root() {
  local root=$1 commit=$2 label=$3
  git -C "$root" cat-file -e "$commit^{commit}" 2>/dev/null || die "$label commit is not present in owning repository"
}

require_role_pair() {
  local role=$1 owner parent candidate root_var root
  owner=$(role_owner "$role")
  parent=$(role_parent "$role")
  candidate=$(role_candidate "$role")
  root_var=$(owner_root_var "$owner")
  root=${!root_var}
  require_commit_in_root "$root" "$parent" "$role parent"
  require_commit_in_root "$root" "$candidate" "$role candidate"
  [ "$parent" != "$candidate" ] || die "$role parent and candidate must differ"
  git -C "$root" merge-base --is-ancestor "$parent" "$candidate" || die "$role parent is not an ancestor of candidate"
}

require_selected_commit() {
  local owner=$1 commit=$2 role_label=$3 root_var head_var root head
  root_var=$(owner_root_var "$owner")
  head_var=$(owner_commit_var "$owner")
  root=${!root_var}
  head=${!head_var}
  require_commit_in_root "$root" "$commit" "$role_label selected"
  [ "$head" = "$commit" ] || die "$role_label selected commit must equal checked-out owner HEAD"
}

verify_composed_contains() {
  local role=$1 owner candidate root_var root head_var head label
  owner=$(role_owner "$role")
  candidate=$(role_candidate "$role")
  root_var=$(owner_root_var "$owner")
  head_var=$(owner_commit_var "$owner")
  root=${!root_var}
  head=${!head_var}
  label="composed $role"
  require_commit_in_root "$root" "$candidate" "$label candidate"
  git -C "$root" merge-base --is-ancestor "$candidate" "$head" || die "$label candidate is not contained in composed owner HEAD; composition must provide an accepted explicit source-delta manifest in the later provenance slice"
}

verify_composed_tip_contains() {
  local owner=$1 commit=$2 root_var root head_var head
  root_var=$(owner_root_var "$owner")
  head_var=$(owner_commit_var "$owner")
  root=${!root_var}
  head=${!head_var}
  require_commit_in_root "$root" "$commit" "composed T66 dependency"
  git -C "$root" merge-base --is-ancestor "$commit" "$head" || die "composed T66 dependency is not contained in Bus Engine OS HEAD; composition must provide an accepted explicit source-delta manifest in the later provenance slice"
}

scenario_json() {
  if [ "$CASE_ID" = "composed" ]; then
    cat <<EOF
{"format":"$(json_escape "$TUPLE_FORMAT")","resolver":"$(json_escape "$BUS_GATE2_RESOLVER_SHA256:$BUS_GATE2_RESOLVER_SIZE")","bundle":"$(json_escape "$BUS_GATE2_BUNDLE_DIR_SHA256:$BUS_GATE2_BUNDLE_DIR_SIZE")","kernel":"$(json_escape "$BUS_GATE2_KERNEL_SHA256:$BUS_GATE2_KERNEL_SIZE")","rootfs":"$(json_escape "$BUS_GATE2_ROOTFS_SHA256:$BUS_GATE2_ROOTFS_SIZE")","qemu_js":"$(json_escape "$BUS_GATE2_QEMU_JS_SHA256:$BUS_GATE2_QEMU_JS_SIZE")","qemu_wasm":"$(json_escape "$BUS_GATE2_QEMU_WASM_SHA256:$BUS_GATE2_QEMU_WASM_SIZE")","heavy_lock_path":"$(json_escape "$(heavy_lock_expected_path)")","heavy_lock_non_overlap":true,"g4_network":"none","g4_timeout_ms":1200000,"g4_outer_seconds":1260,"qemu_args":["-device","virtio-rng-device"],"service_request":{"operation":"initialize","timeout_ms":10000},"kernel_enablement":"bus.engine.codex_app_server=1","console_readiness_marker":"bus-engine-os login:","console_duplex_primary_serial":true,"storage_marker":"$(json_escape "$BUS_GATE2_STORAGE_MARKER")"}
EOF
    return
  fi
  cat <<EOF
{"format":"$(json_escape "$TUPLE_FORMAT")","resolver":"$(json_escape "$BUS_GATE2_RESOLVER_SHA256:$BUS_GATE2_RESOLVER_SIZE")","bundle":"$(json_escape "$BUS_GATE2_BUNDLE_DIR_SHA256:$BUS_GATE2_BUNDLE_DIR_SIZE")","kernel":"$(json_escape "$BUS_GATE2_KERNEL_SHA256:$BUS_GATE2_KERNEL_SIZE")","rootfs":"$(json_escape "$BUS_GATE2_ROOTFS_SHA256:$BUS_GATE2_ROOTFS_SIZE")","qemu_js":"$(json_escape "$BUS_GATE2_QEMU_JS_SHA256:$BUS_GATE2_QEMU_JS_SIZE")","qemu_wasm":"$(json_escape "$BUS_GATE2_QEMU_WASM_SHA256:$BUS_GATE2_QEMU_WASM_SIZE")","heavy_lock_path":"$(json_escape "$(heavy_lock_expected_path)")","heavy_lock_non_overlap":true,"g4_network":"none","g4_timeout_ms":1200000,"g4_outer_seconds":1260,"qemu_args":["-device","virtio-rng-device"],"serial_after":"QEMU_WASM_SNAPSHOT_READY","serial_text_sha256":"$(json_escape "$BUS_GATE2_G4_SERIAL_INPUT_SHA256")","storage_marker":"$(json_escape "$BUS_GATE2_STORAGE_MARKER")"}
EOF
}

verified_fixed_roles_json() {
  if [ "$CASE_ID" = "composed" ]; then
    cat <<EOF
{"t64":{"owner":"$(json_escape "$ROLE_T64_OWNER")","parent":"$(json_escape "$ROLE_T64_PARENT")","candidate":"$(json_escape "$ROLE_T64_CANDIDATE")"},"t65":{"owner":"$(json_escape "$ROLE_T65_OWNER")","parent":"$(json_escape "$ROLE_T65_PARENT")","candidate":"$(json_escape "$ROLE_T65_CANDIDATE")"},"t154":{"owner":"$(json_escape "$ROLE_T154_OWNER")","parent":"$(json_escape "$ROLE_T154_PARENT")","candidate":"$(json_escape "$ROLE_T154_CANDIDATE")"},"t66":{"owner":"$(json_escape "$ROLE_T66_OWNER")","tip":"$(json_escape "$ROLE_T66_TIP")"}}
EOF
    return
  fi
  cat <<EOF
{"t50":{"owner":"$(json_escape "$ROLE_T50_OWNER")","parent":"$(json_escape "$ROLE_T50_PARENT")","candidate":"$(json_escape "$ROLE_T50_CANDIDATE")"},"t64":{"owner":"$(json_escape "$ROLE_T64_OWNER")","parent":"$(json_escape "$ROLE_T64_PARENT")","candidate":"$(json_escape "$ROLE_T64_CANDIDATE")"},"t65":{"owner":"$(json_escape "$ROLE_T65_OWNER")","parent":"$(json_escape "$ROLE_T65_PARENT")","candidate":"$(json_escape "$ROLE_T65_CANDIDATE")"},"t154":{"owner":"$(json_escape "$ROLE_T154_OWNER")","parent":"$(json_escape "$ROLE_T154_PARENT")","candidate":"$(json_escape "$ROLE_T154_CANDIDATE")"},"t66":{"owner":"$(json_escape "$ROLE_T66_OWNER")","tip":"$(json_escape "$ROLE_T66_TIP")"}}
EOF
}

composed_containment_json() {
  if [ "$CASE_ID" = "composed" ]; then
    cat <<EOF
{"bus_engine_os_t64":"$(json_escape "$VERIFIED_COMPOSED_BEO_CONTAINS_T64")","bus_engine_os_t66":"$(json_escape "$VERIFIED_COMPOSED_BEO_CONTAINS_T66")","qemu_t65":"$(json_escape "$VERIFIED_COMPOSED_QEMU_CONTAINS_T65")","qemu_t154":"$(json_escape "$VERIFIED_COMPOSED_QEMU_CONTAINS_T154")"}
EOF
    return
  fi
  cat <<EOF
{"bus_engine_os_t50":"","bus_engine_os_t64":"$(json_escape "$VERIFIED_COMPOSED_BEO_CONTAINS_T64")","bus_engine_os_t66":"$(json_escape "$VERIFIED_COMPOSED_BEO_CONTAINS_T66")","qemu_t65":"$(json_escape "$VERIFIED_COMPOSED_QEMU_CONTAINS_T65")","qemu_t154":"$(json_escape "$VERIFIED_COMPOSED_QEMU_CONTAINS_T154")"}
EOF
}

delta_json() {
  cat <<EOF
{"case":"$(json_escape "$CASE_ID")","role":"$(json_escape "$ROLE")","verified_owner":"$(json_escape "$VERIFIED_ROLE_OWNER")","verified_parent":"$(json_escape "$VERIFIED_ROLE_PARENT")","verified_candidate":"$(json_escape "$VERIFIED_ROLE_CANDIDATE")","selected_commit":"$(json_escape "$VERIFIED_SELECTED_COMMIT")","relationship_result":"$(json_escape "$VERIFIED_RELATIONSHIP_RESULT")","verified_fixed_roles":$(verified_fixed_roles_json | LC_ALL=C tr -d '\n'),"composed_containment":$(composed_containment_json | LC_ALL=C tr -d '\n'),"fixed_failure":{"gate":"$(json_escape "$FIXED_FAIL_GATE")","predicate":"$(json_escape "$FIXED_FAIL_PREDICATE")"}}
EOF
}

write_environment_manifest() {
  local file=$1
  {
    printf 'ROOT_DIR=%s\n' "$ROOT_DIR"
    printf 'CASE_ID=%s\n' "$CASE_ID"
    printf 'ROLE=%s\n' "$ROLE"
    printf 'FORMAT=%s\n' "$TUPLE_FORMAT"
    printf 'BUS_GATE2_RESULT_DIR=%s\n' "$RESULT_DIR"
    printf 'BUS_GATE2_SCENARIO_DIGEST=%s\n' "$BUS_GATE2_SCENARIO_DIGEST"
    printf 'BUS_GATE2_ACTIVE_SOURCE_OWNER=%s\n' "$BUS_GATE2_ACTIVE_SOURCE_OWNER"
    printf 'BUS_GATE2_ACTIVE_SOURCE_COMMIT=%s\n' "$BUS_GATE2_ACTIVE_SOURCE_COMMIT"
    printf 'BUS_GATE2_BUSDK_COMMIT=%s\n' "$BUS_GATE2_BUSDK_COMMIT"
    printf 'BUS_GATE2_BUS_ENGINE_OS_COMMIT=%s\n' "$BUS_GATE2_BUS_ENGINE_OS_COMMIT"
    printf 'BUS_GATE2_QEMU_COMMIT=%s\n' "$BUS_GATE2_QEMU_COMMIT"
    printf 'BUS_GATE2_OPENAI_CODEX_COMMIT=%s\n' "$BUS_GATE2_OPENAI_CODEX_COMMIT"
    printf 'BUS_GATE2_BROWSER_IMAGE_ID=%s\n' "$BUS_GATE2_BROWSER_IMAGE_ID"
    printf 'BUS_GATE2_HEAVY_LOCK_FD=%s\n' "$BUS_GATE2_HEAVY_LOCK_FD"
    printf 'BUS_GATE2_HEAVY_LOCK_PATH=%s\n' "$(heavy_lock_expected_path)"
  } >"$file"
}

write_artifact_manifest() {
  local file=$1 t50_pins=""
  if [ "$CASE_ID" != "composed" ]; then
    t50_pins=$(cat <<EOF
    "t50_parent": "$(json_escape "$BUS_GATE2_T50_PARENT_COMMIT")",
    "t50_candidate": "$(json_escape "$BUS_GATE2_T50_CANDIDATE_COMMIT")",
EOF
)
  fi
  cat >"$file" <<EOF
{
  "pins": {
    "busdk": "$(json_escape "$BUS_GATE2_BUSDK_COMMIT")",
    "bus_engine_os": "$(json_escape "$BUS_GATE2_BUS_ENGINE_OS_COMMIT")",
    "qemu": "$(json_escape "$BUS_GATE2_QEMU_COMMIT")",
    "openai_codex": "$(json_escape "$BUS_GATE2_OPENAI_CODEX_COMMIT")",
$t50_pins
    "t64_parent": "$(json_escape "$BUS_GATE2_T64_PARENT_COMMIT")",
    "t64_candidate": "$(json_escape "$BUS_GATE2_T64_CANDIDATE_COMMIT")",
    "t65_parent": "$(json_escape "$BUS_GATE2_T65_PARENT_COMMIT")",
    "t65_candidate": "$(json_escape "$BUS_GATE2_T65_CANDIDATE_COMMIT")",
    "t154_parent": "$(json_escape "$BUS_GATE2_T154_PARENT_COMMIT")",
    "t154_candidate": "$(json_escape "$BUS_GATE2_T154_CANDIDATE_COMMIT")",
    "t66_tip": "$(json_escape "$BUS_GATE2_T66_TIP_COMMIT")"
  },
  "qemu_source_split": {
    "host_gate_candidate": "$(json_escape "$BUS_GATE2_QEMU_COMMIT")",
    "compiled_artifact_source": "$(json_escape "$QEMU_COMPILED_SOURCE_COMMIT")",
    "compiled_inputs_changed": false,
    "allowed_candidate_paths": [
      "scripts/ci/wasm-browser-cdp-gate.mjs",
      "scripts/ci/wasm-browser-cdp-gate-test.mjs",
      "scripts/ci/wasm-browser-cdp-proof-gate.mjs",
      "scripts/ci/wasm-browser-cdp-proof-gate-test.mjs"
    ]
  },
  "artifacts": {
    "kernel": {"path":"$(json_escape "$BUS_GATE2_KERNEL")","size_bytes":$BUS_GATE2_KERNEL_SIZE,"sha256":"$BUS_GATE2_KERNEL_SHA256"},
    "rootfs": {"path":"$(json_escape "$BUS_GATE2_ROOTFS")","size_bytes":$BUS_GATE2_ROOTFS_SIZE,"sha256":"$BUS_GATE2_ROOTFS_SHA256","profile":"virtual-server","arch":"riscv64"},
    "resolver": {"path":"$(json_escape "$BUS_GATE2_RESOLVER")","size_bytes":$BUS_GATE2_RESOLVER_SIZE,"sha256":"$BUS_GATE2_RESOLVER_SHA256"},
    "qemu_js": {"path":"$(json_escape "$BUS_GATE2_QEMU_JS")","size_bytes":$BUS_GATE2_QEMU_JS_SIZE,"sha256":"$BUS_GATE2_QEMU_JS_SHA256"},
    "qemu_wasm": {"path":"$(json_escape "$BUS_GATE2_QEMU_WASM")","size_bytes":$BUS_GATE2_QEMU_WASM_SIZE,"sha256":"$BUS_GATE2_QEMU_WASM_SHA256"},
    "bundle": {"path":"$(json_escape "$BUS_GATE2_BUNDLE_DIR")","size_bytes":$BUS_GATE2_BUNDLE_DIR_SIZE,"sha256":"$BUS_GATE2_BUNDLE_DIR_SHA256"},
    "export_manifest": {"path":"$(json_escape "$BUS_GATE2_EXPORT_MANIFEST")","size_bytes":$BUS_GATE2_EXPORT_MANIFEST_SIZE,"sha256":"$BUS_GATE2_EXPORT_MANIFEST_SHA256"},
    "export_sha256s": {"path":"$(json_escape "$BUS_GATE2_SHA256SUMS")","size_bytes":$BUS_GATE2_SHA256SUMS_SIZE,"sha256":"$BUS_GATE2_SHA256SUMS_SHA256"},
    "package_report": {"path":"$(json_escape "$BUS_GATE2_PACKAGE_REPORT")","size_bytes":$BUS_GATE2_PACKAGE_REPORT_SIZE,"sha256":"$BUS_GATE2_PACKAGE_REPORT_SHA256"},
    "release_report": {"path":"$(json_escape "$BUS_GATE2_RELEASE_REPORT")","size_bytes":$BUS_GATE2_RELEASE_REPORT_SIZE,"sha256":"$BUS_GATE2_RELEASE_REPORT_SHA256"}
  }
}
EOF
}

validate_role() {
  case "$ROLE" in
    parent-fail)
      [ "$CASE_ID" != "composed" ] || die "composed does not support parent-fail controls"
      [ "$CASE_ID" != "T64" ] || die "T64 parent-fail has no packet-owned package/import-wrapper predicate; later provenance slice must supply an accepted explicit control"
      FIXED_FAIL_GATE=$(role_parent_fail_gate "$CASE_ID")
      FIXED_FAIL_PREDICATE=$(role_parent_fail_predicate "$CASE_ID")
      if [ -n "$EXPECTED_FAIL_GATE" ] && [ "$EXPECTED_FAIL_GATE" != "$FIXED_FAIL_GATE" ]; then
        die "parent-fail gate is harness-owned for $CASE_ID: expected $FIXED_FAIL_GATE"
      fi
      if [ -n "$EXPECTED_FAIL_PREDICATE" ] && [ "$EXPECTED_FAIL_PREDICATE" != "$FIXED_FAIL_PREDICATE" ]; then
        die "parent-fail predicate is harness-owned for $CASE_ID"
      fi
      EXPECTED_FAIL_GATE=$FIXED_FAIL_GATE
      EXPECTED_FAIL_PREDICATE=$FIXED_FAIL_PREDICATE
      ;;
    candidate-pass)
      [ -z "$EXPECTED_FAIL_GATE" ] || die "--expected-fail-gate is only valid for parent-fail"
      [ -z "$EXPECTED_FAIL_PREDICATE" ] || die "--expected-fail-predicate is only valid for parent-fail"
      FIXED_FAIL_GATE=""
      FIXED_FAIL_PREDICATE=""
      ;;
    *) die "--role must be parent-fail or candidate-pass" ;;
  esac
  case "$CASE_ID" in T50|T64|T65|composed) ;; *) die "--case must be T50, T64, T65, or composed" ;; esac
}

validate_case_binding() {
  require_var BUS_GATE2_ACTIVE_SOURCE_OWNER
  require_40hex BUS_GATE2_ACTIVE_SOURCE_COMMIT
  if [ "$CASE_ID" != "composed" ]; then
    require_role_pair T50
    [ "$BUS_GATE2_T50_PARENT_COMMIT" = "$ROLE_T50_PARENT" ] || die "BUS_GATE2_T50_PARENT_COMMIT must equal fixed T50 parent"
    [ "$BUS_GATE2_T50_CANDIDATE_COMMIT" = "$ROLE_T50_CANDIDATE" ] || die "BUS_GATE2_T50_CANDIDATE_COMMIT must equal fixed T50 candidate"
  fi
  require_role_pair T64
  require_role_pair T65
  require_role_pair T154
  require_commit_in_root "$BUS_GATE2_BUS_ENGINE_OS_ROOT" "$ROLE_T66_TIP" "T66 dependency"
  [ "$BUS_GATE2_T64_PARENT_COMMIT" = "$ROLE_T64_PARENT" ] || die "BUS_GATE2_T64_PARENT_COMMIT must equal fixed T64 parent"
  [ "$BUS_GATE2_T64_CANDIDATE_COMMIT" = "$ROLE_T64_CANDIDATE" ] || die "BUS_GATE2_T64_CANDIDATE_COMMIT must equal fixed T64 candidate"
  [ "$BUS_GATE2_T65_PARENT_COMMIT" = "$ROLE_T65_PARENT" ] || die "BUS_GATE2_T65_PARENT_COMMIT must equal fixed T65 parent"
  [ "$BUS_GATE2_T65_CANDIDATE_COMMIT" = "$ROLE_T65_CANDIDATE" ] || die "BUS_GATE2_T65_CANDIDATE_COMMIT must equal fixed T65 candidate"
  [ "$BUS_GATE2_T154_PARENT_COMMIT" = "$ROLE_T154_PARENT" ] || die "BUS_GATE2_T154_PARENT_COMMIT must equal fixed T154 parent"
  [ "$BUS_GATE2_T154_CANDIDATE_COMMIT" = "$ROLE_T154_CANDIDATE" ] || die "BUS_GATE2_T154_CANDIDATE_COMMIT must equal fixed T154 candidate"
  [ "$BUS_GATE2_T66_TIP_COMMIT" = "$ROLE_T66_TIP" ] || die "BUS_GATE2_T66_TIP_COMMIT must equal fixed T66 dependency"
  local actual_owner_commit
  case "$BUS_GATE2_ACTIVE_SOURCE_OWNER" in
    bus_engine_os)
      actual_owner_commit=$(git_head "$BUS_GATE2_BUS_ENGINE_OS_ROOT")
      [ "$BUS_GATE2_BUS_ENGINE_OS_COMMIT" = "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" ] || die "active BEO source must equal BUS_GATE2_BUS_ENGINE_OS_COMMIT"
      ;;
    qemu)
      actual_owner_commit=$(git_head "$BUS_GATE2_QEMU_ROOT")
      [ "$BUS_GATE2_QEMU_COMMIT" = "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" ] || die "active QEMU source must equal BUS_GATE2_QEMU_COMMIT"
      ;;
    openai_codex)
      actual_owner_commit=$(git_head "$BUS_GATE2_OPENAI_CODEX_ROOT")
      [ "$BUS_GATE2_OPENAI_CODEX_COMMIT" = "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" ] || die "active OpenAI Codex source must equal BUS_GATE2_OPENAI_CODEX_COMMIT"
      ;;
    *) die "BUS_GATE2_ACTIVE_SOURCE_OWNER must be bus_engine_os, qemu, or openai_codex" ;;
  esac
  [ "$actual_owner_commit" = "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" ] || die "active source commit does not match actual checked-out HEAD"
  VERIFIED_ROLE_OWNER=""
  VERIFIED_ROLE_PARENT=""
  VERIFIED_ROLE_CANDIDATE=""
  VERIFIED_SELECTED_COMMIT="$BUS_GATE2_ACTIVE_SOURCE_COMMIT"
  VERIFIED_RELATIONSHIP_RESULT="verified-ancestor"
  VERIFIED_COMPOSED_BEO_CONTAINS_T64=""
  VERIFIED_COMPOSED_BEO_CONTAINS_T66=""
  VERIFIED_COMPOSED_QEMU_CONTAINS_T65=""
  VERIFIED_COMPOSED_QEMU_CONTAINS_T154=""
  case "$CASE_ID:$ROLE" in
    T50:parent-fail|T50:candidate-pass|T64:parent-fail|T64:candidate-pass|T65:parent-fail|T65:candidate-pass)
      local expected_owner expected_commit
      expected_owner=$(role_owner "$CASE_ID")
      if [ "$ROLE" = "parent-fail" ]; then expected_commit=$(role_parent "$CASE_ID"); else expected_commit=$(role_candidate "$CASE_ID"); fi
      [ "$BUS_GATE2_ACTIVE_SOURCE_OWNER" = "$expected_owner" ] || die "$CASE_ID $ROLE must bind the fixed owning repository"
      [ "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" = "$expected_commit" ] || die "$CASE_ID $ROLE must bind the fixed expected commit"
      require_selected_commit "$expected_owner" "$expected_commit" "$CASE_ID $ROLE"
      VERIFIED_ROLE_OWNER=$expected_owner
      VERIFIED_ROLE_PARENT=$(role_parent "$CASE_ID")
      VERIFIED_ROLE_CANDIDATE=$(role_candidate "$CASE_ID")
      ;;
    composed:candidate-pass)
      [ "$BUS_GATE2_ACTIVE_SOURCE_OWNER" = "bus_engine_os" ] || die "composed candidate-pass must bind fixed Bus Engine OS owner"
      [ "$BUS_GATE2_ACTIVE_SOURCE_COMMIT" = "$BUS_GATE2_BUS_ENGINE_OS_COMMIT" ] || die "composed candidate-pass must select Bus Engine OS HEAD"
      verify_composed_contains T64
      VERIFIED_COMPOSED_BEO_CONTAINS_T64=true
      verify_composed_tip_contains bus_engine_os "$ROLE_T66_TIP"
      VERIFIED_COMPOSED_BEO_CONTAINS_T66=true
      verify_composed_contains T65
      VERIFIED_COMPOSED_QEMU_CONTAINS_T65=true
      verify_composed_contains T154
      VERIFIED_COMPOSED_QEMU_CONTAINS_T154=true
      VERIFIED_ROLE_OWNER="$BUS_GATE2_ACTIVE_SOURCE_OWNER"
      VERIFIED_RELATIONSHIP_RESULT="verified-composed-containment"
      ;;
    composed:parent-fail) die "composed does not support parent-fail controls" ;;
  esac
  export VERIFIED_ROLE_OWNER VERIFIED_ROLE_PARENT VERIFIED_ROLE_CANDIDATE VERIFIED_SELECTED_COMMIT VERIFIED_RELATIONSHIP_RESULT
  export VERIFIED_COMPOSED_BEO_CONTAINS_T64 VERIFIED_COMPOSED_BEO_CONTAINS_T66 VERIFIED_COMPOSED_QEMU_CONTAINS_T65 VERIFIED_COMPOSED_QEMU_CONTAINS_T154 FIXED_FAIL_GATE FIXED_FAIL_PREDICATE
}

validate_identity_inputs() {
  local current_head scenario
  require_40hex BUS_GATE2_BUSDK_COMMIT
  current_head=$(git_head "$ROOT_DIR")
  [ "$current_head" = "$BUS_GATE2_BUSDK_COMMIT" ] || die "BUS_GATE2_BUSDK_COMMIT mismatch: expected $BUS_GATE2_BUSDK_COMMIT, got $current_head"
  require_git_root_clean BUS_GATE2_BUS_ENGINE_OS_ROOT
  require_git_root_clean BUS_GATE2_QEMU_ROOT
  require_git_root_clean BUS_GATE2_OPENAI_CODEX_ROOT
  require_git_head BUS_GATE2_BUS_ENGINE_OS_ROOT BUS_GATE2_BUS_ENGINE_OS_COMMIT
  require_git_head BUS_GATE2_QEMU_ROOT BUS_GATE2_QEMU_COMMIT
  require_git_head BUS_GATE2_OPENAI_CODEX_ROOT BUS_GATE2_OPENAI_CODEX_COMMIT
  require_busdk_gitlink_pin BUS_GATE2_BUS_ENGINE_OS_SUBMODULE_PATH BUS_GATE2_BUS_ENGINE_OS_COMMIT
  if [ "$CASE_ID" != "composed" ]; then
    require_40hex BUS_GATE2_T50_PARENT_COMMIT
    require_40hex BUS_GATE2_T50_CANDIDATE_COMMIT
  fi
  require_40hex BUS_GATE2_T64_PARENT_COMMIT
  require_40hex BUS_GATE2_T64_CANDIDATE_COMMIT
  require_40hex BUS_GATE2_T65_PARENT_COMMIT
  require_40hex BUS_GATE2_T65_CANDIDATE_COMMIT
  require_40hex BUS_GATE2_T154_PARENT_COMMIT
  require_40hex BUS_GATE2_T154_CANDIDATE_COMMIT
  require_40hex BUS_GATE2_T66_TIP_COMMIT
  require_docker_id BUS_GATE2_BROWSER_IMAGE_ID
  if [ "$CASE_ID" != "composed" ]; then
    require_64hex BUS_GATE2_G4_SERIAL_INPUT_SHA256
  fi
  validate_case_binding

  require_artifact BUS_GATE2_KERNEL BUS_GATE2_KERNEL_SIZE BUS_GATE2_KERNEL_SHA256
  require_artifact BUS_GATE2_ROOTFS BUS_GATE2_ROOTFS_SIZE BUS_GATE2_ROOTFS_SHA256
  require_artifact BUS_GATE2_RESOLVER BUS_GATE2_RESOLVER_SIZE BUS_GATE2_RESOLVER_SHA256
  require_artifact BUS_GATE2_QEMU_JS BUS_GATE2_QEMU_JS_SIZE BUS_GATE2_QEMU_JS_SHA256
  require_artifact BUS_GATE2_QEMU_WASM BUS_GATE2_QEMU_WASM_SIZE BUS_GATE2_QEMU_WASM_SHA256
  [ "$BUS_GATE2_QEMU_JS_SHA256" = "$QEMU_COMPILED_JS_SHA256" ] || die "QEMU JS must remain the reused 200ae823 artifact"
  [ "$BUS_GATE2_QEMU_WASM_SHA256" = "$QEMU_COMPILED_WASM_SHA256" ] || die "QEMU WASM must remain the reused 200ae823 artifact"
  require_artifact BUS_GATE2_EXPORT_MANIFEST BUS_GATE2_EXPORT_MANIFEST_SIZE BUS_GATE2_EXPORT_MANIFEST_SHA256
  require_artifact BUS_GATE2_SHA256SUMS BUS_GATE2_SHA256SUMS_SIZE BUS_GATE2_SHA256SUMS_SHA256
  require_artifact BUS_GATE2_PACKAGE_REPORT BUS_GATE2_PACKAGE_REPORT_SIZE BUS_GATE2_PACKAGE_REPORT_SHA256
  require_artifact BUS_GATE2_RELEASE_REPORT BUS_GATE2_RELEASE_REPORT_SIZE BUS_GATE2_RELEASE_REPORT_SHA256
  require_bundle BUS_GATE2_BUNDLE_DIR BUS_GATE2_BUNDLE_DIR_SIZE BUS_GATE2_BUNDLE_DIR_SHA256
  require_path_file BUS_GATE2_RELEASE_LEDGER
  require_var BUS_GATE2_G4_CONTAINER_NAME
  require_var BUS_GATE2_STORAGE_MARKER
  require_var BUS_GATE2_CHROMIUM_TAG
  if [ "$CASE_ID" != "composed" ]; then
    require_path_file BUS_GATE2_G4_SERIAL_INPUT_FILE
  fi
  validate_heavy_lock_non_overlap >/dev/null

  scenario=$(scenario_json | LC_ALL=C tr -d '\n')
  BUS_GATE2_SCENARIO_DIGEST=$(sha256_text "$scenario")
  export BUS_GATE2_SCENARIO_DIGEST
}

require_packet_paths() {
  local script
  if [ "$CASE_ID" = "T65" ]; then
    for script in \
      scripts/ci/wasm-chardev-emscripten-abi-test.mjs \
      scripts/ci/wasm-chardev-startup-guard-test.mjs \
      scripts/ci/wasm-build-smoke-initramfs-test.py; do
      git -C "$BUS_GATE2_QEMU_ROOT" cat-file -e "$ROLE_T65_CANDIDATE:$script" 2>/dev/null ||
        die "fixed T65 candidate test missing: $script"
    done
  else
    for script in \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-smoke-args-test.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-smoke-runner-test.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-gate-test.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-proof-gate.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-proof-gate-test.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-guest-manifest-test.mjs" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-prepare-tuxboot-smoke-guest-test.py" \
      "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-gate.mjs"; do
      require_script "$script"
    done
  fi
  for script in \
    "$BUS_GATE2_BUS_ENGINE_OS_ROOT/scripts/bus-boot-test" \
    "$BUS_GATE2_BUS_ENGINE_OS_ROOT/scripts/bus-check-boot-test-report" \
    "$BUS_GATE2_BUS_ENGINE_OS_ROOT/scripts/bus-check-browser-hosted-release"; do
    require_script "$script"
  done
}

validate_qemu_host_only_range() {
  local base=$QEMU_COMPILED_SOURCE_COMMIT candidate=$BUS_GATE2_QEMU_COMMIT
  local actual expected
  require_commit_in_root "$BUS_GATE2_QEMU_ROOT" "$base" "compiled QEMU artifact source"
  require_commit_in_root "$BUS_GATE2_QEMU_ROOT" "$candidate" "QEMU host gate candidate"
  git -C "$BUS_GATE2_QEMU_ROOT" merge-base --is-ancestor "$base" "$candidate" ||
    die "QEMU host gate candidate is not based on compiled artifact source"
  actual=$(git -C "$BUS_GATE2_QEMU_ROOT" diff --name-only --diff-filter=ACDMRTUXB "$base..$candidate" | LC_ALL=C sort)
  expected=$(printf '%s\n' \
    scripts/ci/wasm-browser-cdp-gate-test.mjs \
    scripts/ci/wasm-browser-cdp-gate.mjs \
    scripts/ci/wasm-browser-cdp-proof-gate-test.mjs \
    scripts/ci/wasm-browser-cdp-proof-gate.mjs | LC_ALL=C sort)
  [ "$actual" = "$expected" ] ||
    die "QEMU candidate range must contain only the four host gate/proof files"
  printf 'compiled_artifact_source=%s\nhost_gate_candidate=%s\ncompiled_inputs_changed=false\n' \
    "$base" "$candidate"
}

validate_bundle_kernel_enablement() {
  python3 - "$BUS_GATE2_EXPORT_MANIFEST" "$QEMU_COMPILED_SOURCE_COMMIT" \
    "$QEMU_COMPILED_JS_SHA256" "$QEMU_COMPILED_WASM_SHA256" <<'PY'
import json
import shlex
import sys

path, qemu_source, js_sha, wasm_sha = sys.argv[1:5]
with open(path, encoding="utf-8") as handle:
    doc = json.load(handle)
append = doc.get("default_parameters", {}).get("kernelAppend")
if not isinstance(append, str):
    raise SystemExit("bundle manifest lacks default_parameters.kernelAppend")
tokens = shlex.split(append)
want = "bus.engine.codex_app_server=1"
enablement = [token for token in tokens if token.startswith("bus.engine.codex_app_server=")]
if enablement != [want]:
    raise SystemExit("bundle manifest must contain exactly one bus.engine.codex_app_server=1 token")
roles = {}
for entry in doc.get("files", []):
    if isinstance(entry, dict) and entry.get("role") in ("qemu-javascript", "qemu-wasm"):
        roles.setdefault(entry["role"], []).append(entry.get("sha256"))
if roles.get("qemu-javascript") != [js_sha]:
    raise SystemExit("bundle manifest QEMU JavaScript hash is not the reused 200ae823 artifact")
if roles.get("qemu-wasm") != [wasm_sha]:
    raise SystemExit("bundle manifest QEMU WASM hash is not the reused 200ae823 artifact")
print(json.dumps({
    "kernel_enablement": want,
    "kernel_enablement_count": 1,
    "qemu_compiled_artifact_source": qemu_source,
    "qemu_javascript_sha256": js_sha,
    "qemu_wasm_sha256": wasm_sha,
}, sort_keys=True))
PY
}

validate_codex_package_reports() {
  python3 - "$BUS_GATE2_PACKAGE_REPORT" "$BUS_GATE2_RELEASE_REPORT" \
    "$BUS_GATE2_BUS_ENGINE_OS_COMMIT" <<'PY'
import json
import hashlib
import posixpath
import re
import sys
import tarfile
from pathlib import Path

package_path, release_path, beo_commit = sys.argv[1:4]
with open(package_path, encoding="utf-8") as handle:
    package_report = json.load(handle)
with open(release_path, encoding="utf-8") as handle:
    release_report = json.load(handle)
if package_report.get("format") != "thread64-package-import-e2e-result-v1":
    raise SystemExit("wrong Codex package report format")
if package_report.get("result") != "PASS":
    raise SystemExit("Codex package report did not pass")
package = package_report.get("package")
if not isinstance(package, dict):
    raise SystemExit("Codex package report lacks package content")
package_id = package.get("id")
if not isinstance(package_id, str) or not re.fullmatch(
    r"codex-app-server-[0-9][0-9A-Za-z.+~-]*-[0-9]+\.riscv64", package_id
):
    raise SystemExit("package report does not identify a RISC-V64 codex-app-server package")
sha_re = re.compile(r"[0-9a-f]{64}")
archive_sha = package.get("archive_sha256")
binary_sha = package.get("binary_sha256")
if not isinstance(archive_sha, str) or not sha_re.fullmatch(archive_sha):
    raise SystemExit("package report lacks the Codex package archive SHA-256")
if not isinstance(binary_sha, str) or not sha_re.fullmatch(binary_sha):
    raise SystemExit("package report lacks the Codex App Server binary SHA-256")
archive_path = Path(str(package.get("retained_archive", "")))
if (
    archive_path.name != f"{package_id}.buspkg.tar.gz" or
    not archive_path.is_file()
):
    raise SystemExit("package report lacks the retained RISC-V64 codex-app-server archive")
archive_digest = hashlib.sha256()
with archive_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        archive_digest.update(chunk)
if archive_digest.hexdigest() != archive_sha:
    raise SystemExit("retained Codex package archive SHA-256 mismatch")
binary_path = "/usr/bin/codex-app-server"
archive_binary_path = f"root{binary_path}"
with tarfile.open(archive_path, "r:*") as archive:
    binary_members = [
        member for member in archive.getmembers()
        if member.name.lstrip("./") == archive_binary_path
    ]
    if len(binary_members) != 1:
        raise SystemExit("retained Codex package must contain exactly one /usr/bin/codex-app-server")
    binary_member = binary_members[0]
    expected_link = "../lib/codex-app-server/bin/codex-app-server"
    if not binary_member.issym() or binary_member.linkname != expected_link:
        raise SystemExit("retained /usr/bin/codex-app-server is not the expected package symlink")
    target_path = posixpath.normpath(
        posixpath.join(posixpath.dirname(archive_binary_path), expected_link)
    )
    target_members = [
        member for member in archive.getmembers()
        if member.name.lstrip("./") == target_path and member.isfile()
    ]
    if len(target_members) != 1:
        raise SystemExit("retained Codex App Server package target is missing")
    binary_handle = archive.extractfile(target_members[0])
    if binary_handle is None:
        raise SystemExit("retained Codex App Server binary is unreadable")
    if hashlib.sha256(binary_handle.read()).hexdigest() != binary_sha:
        raise SystemExit("retained /usr/bin/codex-app-server SHA-256 mismatch")
if release_report.get("format") != "bus-engine-os-image-acceptance-v1":
    raise SystemExit("wrong Bus Engine OS release report format")
if release_report.get("status") != "accepted-evidence":
    raise SystemExit("Bus Engine OS release report is not accepted evidence")
if release_report.get("target_arch") != "riscv64":
    raise SystemExit("Bus Engine OS release report is not RISC-V64")
if release_report.get("git_commit") != beo_commit:
    raise SystemExit("Bus Engine OS release report commit mismatch")
profile = release_report.get("image_profile")
if not isinstance(profile, dict) or profile.get("kernel_profile") != "virtual-server":
    raise SystemExit("Bus Engine OS release report is not virtual-server")
if "app-server-bridge-runtime" not in profile.get("package_groups", []):
    raise SystemExit("Bus Engine OS release report lacks the App Server bridge runtime group")
provenance_name = Path(str(release_report.get("provenance", ""))).name
provenance_path = Path(release_path).parent / provenance_name
if not provenance_name or not provenance_path.is_file():
    raise SystemExit("Bus Engine OS release report provenance is unavailable")
with provenance_path.open(encoding="utf-8") as handle:
    provenance = json.load(handle)
if provenance.get("format") != "bus-engine-os-release-metadata-v1":
    raise SystemExit("wrong Bus Engine OS release provenance format")
matches = [
    entry for entry in provenance.get("package_set", [])
    if isinstance(entry, dict) and entry.get("name") == "codex-app-server"
]
if len(matches) != 1:
    raise SystemExit("release provenance must contain exactly one codex-app-server package")
release_package = matches[0]
if (
    release_package.get("id") != package_id or
    release_package.get("architecture") != "riscv64" or
    release_package.get("runtime") is not True or
    release_package.get("sha256") != archive_sha
):
    raise SystemExit("package report does not match the RISC-V64 guest release package")
print(json.dumps({
    "package_id": package_id,
    "architecture": "riscv64",
    "archive_sha256": archive_sha,
    "binary_path": binary_path,
    "binary_sha256": binary_sha,
    "release_commit": beo_commit,
    "release_profile": "virtual-server",
}, sort_keys=True))
PY
}

validate_release_ledger() {
  local path=$1 format=$2
  python3 - "$path" "$format" <<'PY'
import json, sys
path, fmt = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
if doc.get("format") != fmt:
    raise SystemExit("wrong release ledger format")
for key in ("containment", "ordered_down", "zero_survivors", "truthful_telemetry", "control_api_responsive", "supervisor_accepted"):
    if doc.get(key) is not True:
        raise SystemExit(f"missing hard release predicate: {key}")
PY
}

heavy_lock_expected_path() {
  local uid tmp_root
  uid=$(id -u)
  tmp_root=${TMPDIR:-/tmp}
  tmp_root=${tmp_root%/}
  [ "$tmp_root" != / ] || tmp_root=
  printf '%s/busdk-worker-guard-%s/heavy.lock' "$tmp_root" "$uid"
}

validate_heavy_lock_non_overlap() {
  local uid path
  require_decimal BUS_GATE2_HEAVY_LOCK_FD
  [ "$BUS_GATE2_HEAVY_LOCK_FD" -ge 3 ] || die "BUS_GATE2_HEAVY_LOCK_FD must be an inherited descriptor greater than 2"
  uid=$(id -u)
  path=$(heavy_lock_expected_path)
  python3 - "$path" "$uid" "$BUS_GATE2_HEAVY_LOCK_FD" <<'PY'
import fcntl
import os
import stat
import sys

path, uid_text, fd_text = sys.argv[1:4]
uid = int(uid_text)
fd = int(fd_text)
parent, base = os.path.dirname(path), os.path.basename(path)
nofollow = getattr(os, "O_NOFOLLOW", 0)
directory_fd = os.open(parent, os.O_RDONLY | os.O_CLOEXEC | os.O_DIRECTORY | nofollow)
try:
    path_directory = os.lstat(parent)
    open_directory = os.fstat(directory_fd)
    if (path_directory.st_dev, path_directory.st_ino) != (open_directory.st_dev, open_directory.st_ino):
        raise SystemExit("heavy lock directory identity changed while opening")
    if not stat.S_ISDIR(open_directory.st_mode):
        raise SystemExit("heavy lock parent is not a directory")
    if stat.S_IMODE(open_directory.st_mode) != 0o700:
        raise SystemExit("heavy lock directory mode is not 0700")
    if open_directory.st_uid != uid:
        raise SystemExit("heavy lock directory owner mismatch")

    path_lock = os.stat(base, dir_fd=directory_fd, follow_symlinks=False)
    file_stat = os.fstat(fd)
    if (path_lock.st_dev, path_lock.st_ino) != (file_stat.st_dev, file_stat.st_ino):
        raise SystemExit("heavy lock fd path mismatch")
    if not stat.S_ISREG(file_stat.st_mode):
        raise SystemExit("heavy lock is not a regular file")
    if stat.S_IMODE(file_stat.st_mode) != 0o600:
        raise SystemExit("heavy lock mode is not 0600")
    if file_stat.st_uid != uid:
        raise SystemExit("heavy lock file owner mismatch")
    if file_stat.st_nlink != 1:
        raise SystemExit("heavy lock link count is not 1")
    if fcntl.fcntl(fd, fcntl.F_GETFL) & os.O_ACCMODE != os.O_RDWR:
        raise SystemExit("heavy lock fd is not read-write")

    probe = os.open(base, os.O_RDWR | os.O_CLOEXEC | nofollow, dir_fd=directory_fd)
    try:
        try:
            fcntl.flock(probe, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            pass
        else:
            fcntl.flock(probe, fcntl.LOCK_UN)
            raise SystemExit("heavy lock non-overlap is false: lock is not held")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit("heavy lock fd does not own the project lock")
    finally:
        os.close(probe)
finally:
    os.close(directory_fd)

print(f"heavy_lock_path={path}")
print(f"heavy_lock_owner_uid={uid}")
print(f"heavy_lock_fd={fd}")
print("heavy_lock_non_overlap=true")
PY
}

write_final_result() {
  local classification=$1
  OBSERVED_CLASSIFICATION=$classification
  cat >"$RESULT_DIR/final-result.json" <<EOF
{"format":"$TUPLE_FORMAT","case":"$(json_escape "$CASE_ID")","role":"$(json_escape "$ROLE")","expected_fail_gate":"$(json_escape "$EXPECTED_FAIL_GATE")","observed_classification":"$(json_escape "$classification")","scenario_digest":"$(json_escape "$BUS_GATE2_SCENARIO_DIGEST")"}
EOF
}

cleanup_g4() {
  local inspect_before_status
  local rm_status
  local inspect_after_status
  [ -n "$RESULT_DIR" ] || return 0
  [ -n "${BUS_GATE2_G4_CONTAINER_NAME:-}" ] || return 0
  [ "$G4_STARTED" = "1" ] || return 0
  local out_dir="$RESULT_DIR/chromium"
  mkdir -p "$out_dir"
  if [ "$PLAN_MODE" = "1" ]; then
    plan_argv_at "$ROOT_DIR" g4-cleanup-inspect "$out_dir" docker ps -a --filter "name=^/${BUS_GATE2_G4_CONTAINER_NAME}$" --filter "label=bus.thread=42" --filter "label=bus.evidence=$TUPLE_FORMAT" --format '{{.ID}}'
    return 0
  fi
  set +e
  docker ps -a --filter "name=^/${BUS_GATE2_G4_CONTAINER_NAME}$" --filter "label=bus.thread=42" --filter "label=bus.evidence=$TUPLE_FORMAT" --format '{{.ID}}' >"$out_dir/cleanup-before.txt" 2>"$out_dir/cleanup-before.stderr"
  inspect_before_status=$?
  if [ "$inspect_before_status" -ne 0 ]; then
    set -e
    printf 'container_absent=unknown\ncleanup_error=inspect-before-failed\n' >>"$RESULT_DIR/cleanup.log"
    return 1
  fi
  if [ -s "$out_dir/cleanup-before.txt" ]; then
    docker rm -f "$BUS_GATE2_G4_CONTAINER_NAME" >"$out_dir/cleanup-rm.stdout" 2>"$out_dir/cleanup-rm.stderr"
    rm_status=$?
    if [ "$rm_status" -ne 0 ]; then
      set -e
      printf 'container_absent=false\ncleanup_error=remove-failed\n' >>"$RESULT_DIR/cleanup.log"
      return 1
    fi
  fi
  docker ps -a --filter "name=^/${BUS_GATE2_G4_CONTAINER_NAME}$" --filter "label=bus.thread=42" --filter "label=bus.evidence=$TUPLE_FORMAT" --format '{{.ID}}' >"$out_dir/cleanup-after.txt" 2>"$out_dir/cleanup-after.stderr"
  inspect_after_status=$?
  set -e
  if [ "$inspect_after_status" -ne 0 ]; then
    printf 'container_absent=unknown\ncleanup_error=inspect-after-failed\n' >>"$RESULT_DIR/cleanup.log"
    return 1
  fi
  if [ -s "$out_dir/cleanup-after.txt" ]; then
    printf 'container_absent=false\n' >>"$RESULT_DIR/cleanup.log"
    return 1
  fi
  printf 'container_absent=true\n' >>"$RESULT_DIR/cleanup.log"
}

on_exit() {
  local status=$?
  if [ "$G4_STARTED" = "1" ]; then
    cleanup_g4 || return 1
  fi
  return "$status"
}

on_signal() {
  write_final_result signal
  cleanup_g4 || true
  exit 130
}

finish_parent_failure() {
  local gate=$1 stderr_file=$2
  [ "$ROLE" = "parent-fail" ] || die "unexpected candidate failure at $gate"
  [ "$gate" = "$EXPECTED_FAIL_GATE" ] || die "unexpected parent failure gate: expected $EXPECTED_FAIL_GATE, got $gate"
  grep -Fq "$EXPECTED_FAIL_PREDICATE" "$stderr_file" || die "parent failure predicate did not match $stderr_file"
  write_final_result parent-fail
  cleanup_g4
  exit 0
}

write_tuple_from_result() {
  local chromium_dir=$1
  python3 - "$chromium_dir/result.json" "$chromium_dir/g4-generated-exec-proof.stdout" \
    "$RESULT_DIR/tuple.json" "$TUPLE_FORMAT" "$BUS_GATE2_SCENARIO_DIGEST" \
    "$BUS_GATE2_STORAGE_MARKER" <<'PY'
import hashlib
import json
import math
import re
import sys

result_path, proof_path, out_path, fmt, digest, storage_marker = sys.argv[1:7]
with open(result_path, "rb") as handle:
    result_bytes = handle.read()
with open(proof_path, "rb") as handle:
    proof_bytes = handle.read()
result = json.loads(result_bytes)
proof = json.loads(proof_bytes)

def fail(name):
    raise SystemExit(f"runtime roundtrip invariant failed: {name}")

if result.get("success") is not True:
    fail("result.success")
if result.get("marker") != "bus-engine-os login:" or result.get("markerSeen") is not True:
    fail("guest readiness marker")
if result.get("pageErrors") != [] or result.get("resourceErrors") != []:
    fail("browser errors")
if "frontend_roundtrip" in result:
    fail("frontend_roundtrip fabricated surface")
seen = {
    entry.get("text") for entry in result.get("expectedTextSeen", [])
    if isinstance(entry, dict) and entry.get("seen") is True
}
for marker in (
    "QEMU_WASM_SERVICE_READY",
    "bus-engine-os-browser-http-proof: http-ok",
    storage_marker,
):
    if marker not in seen:
        fail(f"expected text {marker}")

roundtrip = result.get("serviceRoundtrip")
if not isinstance(roundtrip, dict):
    fail("serviceRoundtrip")
forbidden = {"body", "payload", "params", "error", "env"}
def reject_forbidden(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key.lower() in forbidden:
                fail(f"forbidden field {key}")
            reject_forbidden(item)
    elif isinstance(value, list):
        for item in value:
            reject_forbidden(item)
reject_forbidden(roundtrip)
request_id = roundtrip.get("requestId")
if not isinstance(request_id, str) or len(request_id) > 64 or not re.fullmatch(
    r"gate2-initialize-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}",
    request_id,
):
    fail("requestId")
if (
    roundtrip.get("source") != "qemuWasmServiceBridge.request" or
    roundtrip.get("operation") != "initialize" or
    roundtrip.get("timeoutMs") != 10000 or
    roundtrip.get("classification") != "success" or
    roundtrip.get("responseProjectionSafe") is not True
):
    fail("request classification")
readiness = roundtrip.get("readiness")
expected_readiness = {
    "readyBefore": True,
    "readyAfter": True,
    "readySourceBefore": "serial",
    "readySourceAfter": "serial",
    "moduleAttachedBefore": True,
    "moduleAttachedAfter": True,
    "interactiveOnlyBefore": True,
    "interactiveOnlyAfter": True,
    "healthRequestedBefore": False,
    "healthRequestedAfter": False,
}
if readiness != expected_readiness:
    fail("readiness attribution")
transport = roundtrip.get("transport")
if not isinstance(transport, dict):
    fail("transport")
for field in (
    "pendingBefore", "pendingAfter", "sentBefore", "sentAfter",
    "receivedBefore", "receivedAfter", "resolvedBefore", "resolvedAfter",
    "timedOutBefore", "timedOutAfter",
):
    if not isinstance(transport.get(field), int) or transport[field] < 0:
        fail(f"transport.{field}")
if transport["pendingBefore"] != 0 or transport["pendingAfter"] != 0:
    fail("pending zero before/after")
if transport["sentAfter"] != transport["sentBefore"] + 1:
    fail("sent delta")
if transport["receivedAfter"] != transport["receivedBefore"] + 1:
    fail("received delta")
if transport["resolvedAfter"] != transport["resolvedBefore"] + 1:
    fail("resolved delta")
if transport["timedOutAfter"] != transport["timedOutBefore"]:
    fail("timeout delta")
if transport.get("lastRequestId") != request_id or transport.get("lastResponseId") != request_id:
    fail("transport request identity")
response = roundtrip.get("response")
expected_response = {
    "id": request_id,
    "operation": "initialize",
    "status": "ok",
    "adapter": "ready",
    "app_server": "initialized",
}
if response != expected_response:
    fail("bounded response projection")
timing = roundtrip.get("timing")
if not isinstance(timing, dict):
    fail("timing")
started = timing.get("startedAtMs")
completed = timing.get("completedAtMs")
elapsed = timing.get("elapsedMs")
if (
    not all(isinstance(value, (int, float)) and math.isfinite(value)
            for value in (started, completed, elapsed)) or
    started < 0 or completed < started or elapsed < 0 or elapsed > 10000 or
    abs(elapsed - (completed - started)) > 0.001
):
    fail("monotonic duration")
if (
    proof.get("ok") is not True or
    proof.get("success") is not True or
    proof.get("generatedExec", {}).get("ok") is not True or
    proof.get("serviceRoundtrip", {}).get("ok") is not True
):
    fail("proof gate")
proof_roundtrip = proof["serviceRoundtrip"]
if (
    proof_roundtrip.get("requestId") != request_id or
    proof_roundtrip.get("operation") != "initialize" or
    proof_roundtrip.get("classification") != "success" or
    proof_roundtrip.get("response") != expected_response or
    proof_roundtrip.get("elapsedMs") != elapsed
):
    fail("proof/result correlation")

tuple_doc = {
    "format": fmt,
    "tuple_id": digest,
    "runtime_result": {
        "sha256": hashlib.sha256(result_bytes).hexdigest(),
        "success": True,
        "marker": result["marker"],
        "marker_seen": True,
        "elapsed_ms": result.get("elapsedMs"),
        "browser": result.get("browserVersion", {}).get("browser"),
        "expected_text_seen": sorted(seen),
    },
    "serviceRoundtrip": roundtrip,
    "proof": {
        "sha256": hashlib.sha256(proof_bytes).hexdigest(),
        "purpose": proof.get("purpose"),
        "ok": True,
        "generatedExec": proof["generatedExec"],
        "serviceRoundtrip": proof_roundtrip,
    },
}
with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(tuple_doc, handle, sort_keys=True, indent=2)
    handle.write("\n")
PY
}

run_t65_g1() {
  local out=$1 test gate test_path
  local test_dir="$out/t65-$ROLE_T65_CANDIDATE"
  mkdir -p "$test_dir"
  for test in \
    scripts/ci/wasm-chardev-emscripten-abi-test.mjs \
    scripts/ci/wasm-chardev-startup-guard-test.mjs \
    scripts/ci/wasm-build-smoke-initramfs-test.py; do
    test_path="$test_dir/$(basename "$test")"
    git -C "$BUS_GATE2_QEMU_ROOT" show "$ROLE_T65_CANDIDATE:$test" >"$test_path"
    gate="g1-qemu-$(basename "$test")"
    case "$test" in
      *.mjs)
        gate=${gate%.mjs}
        gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" env QEMU_TEST_ROOT="$BUS_GATE2_QEMU_ROOT" node "$test_path" ||
          finish_parent_failure "$gate" "$out/${gate}.stderr"
        ;;
      *.py)
        gate=${gate%.py}
        gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" env QEMU_TEST_ROOT="$BUS_GATE2_QEMU_ROOT" python3 "$test_path" ||
          finish_parent_failure "$gate" "$out/${gate}.stderr"
        ;;
    esac
  done
}

run_g1() {
  local out="$RESULT_DIR/static"
  local gate
  mkdir -p "$out"
  if [ "$CASE_ID" = "T65" ]; then
    run_t65_g1 "$out"
    return
  fi
  for test in \
    scripts/ci/wasm-browser-smoke-args-test.mjs \
    scripts/ci/wasm-browser-smoke-runner-test.mjs \
    scripts/ci/wasm-browser-cdp-gate-test.mjs \
    scripts/ci/wasm-browser-cdp-proof-gate-test.mjs \
    scripts/ci/wasm-guest-manifest-test.mjs; do
    gate="g1-qemu-$(basename "$test" .mjs)"
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" node "$test" || finish_parent_failure "$gate" "$out/${gate}.stderr"
  done
  gate=g1-qemu-wasm-prepare-tuxboot-smoke-guest-test
  gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" python3 scripts/ci/wasm-prepare-tuxboot-smoke-guest-test.py || finish_parent_failure "$gate" "$out/${gate}.stderr"
  local flags=(--serial-input-after-text --serial-input-text --pre-serial-input-wait-ms)
  if [ "$CASE_ID" = "composed" ]; then
    gate=g1-qemu-host-only-candidate-range
    gate_argv_at "$ROOT_DIR" "$gate" "$out" validate_qemu_host_only_range || finish_parent_failure "$gate" "$out/${gate}.stderr"
    flags=(--service-request-operation --service-request-timeout-ms --qemu-arg)
  fi
  for flag in "${flags[@]}"; do
    gate="g1-qemu-presence-${flag#--}-gate"
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" rg -F -- "$flag" scripts/ci/wasm-browser-cdp-gate.mjs || finish_parent_failure "$gate" "$out/${gate}.stderr"
    gate="g1-qemu-presence-${flag#--}-test"
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" rg -F -- "$flag" scripts/ci/wasm-browser-cdp-gate-test.mjs || finish_parent_failure "$gate" "$out/${gate}.stderr"
  done
  if [ "$CASE_ID" = "composed" ]; then
    gate=g1-qemu-presence-require-service-roundtrip-gate
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" rg -F -- --require-service-roundtrip scripts/ci/wasm-browser-cdp-proof-gate.mjs || finish_parent_failure "$gate" "$out/${gate}.stderr"
    gate=g1-qemu-presence-require-service-roundtrip-test
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" rg -F -- --require-service-roundtrip scripts/ci/wasm-browser-cdp-proof-gate-test.mjs || finish_parent_failure "$gate" "$out/${gate}.stderr"
    gate=g1-qemu-cdp-parser-fixture
    gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$out" node scripts/ci/wasm-browser-cdp-gate-test.mjs || finish_parent_failure "$gate" "$out/${gate}.stderr"
  fi

  gate=g1-beo-pkgbuild
  gate_argv_at "$BUS_GATE2_BUS_ENGINE_OS_ROOT" "$gate" "$out" go test ./pkg/pkgbuild -run 'TestCodexRiscV64|TestRustCargoSourceBuild' -count=1 || finish_parent_failure "$gate" "$out/${gate}.stderr"
  gate=g1-beo-strict-initialize-bounds-policy
  gate_argv_at "$BUS_GATE2_BUS_ENGINE_OS_ROOT" "$gate" "$out" go test ./tests -run '^(TestCodexBridgeAdapterStrictInitializeFraming|TestCodexBridgeAdapterBoundsRequestWhileStreaming|TestCodexAppServerBridgePolicyBoundary)$' || finish_parent_failure "$gate" "$out/${gate}.stderr"
}

run_harness() {
  trap on_exit EXIT
  trap on_signal INT TERM HUP
  validate_role
  validate_identity_inputs
  require_packet_paths
  ensure_safe_result_dir "$RESULT_DIR"
  RESULT_DIR="$(cd "$RESULT_DIR" && pwd -P)"
  export RESULT_DIR
  : >"$RESULT_DIR/status.tsv"
  printf 'cleanup_policy=exact-container-name-and-labels\n' >"$RESULT_DIR/cleanup.log"
  write_environment_manifest "$RESULT_DIR/environment.env"
  write_artifact_manifest "$RESULT_DIR/artifacts.json"
  scenario_json >"$RESULT_DIR/scenario.json"
  delta_json >"$RESULT_DIR/source-deltas.json"
  printf '%s\n' "$BUS_GATE2_SCENARIO_DIGEST" >"$RESULT_DIR/scenario.sha256"

  local gate
  gate=g0-release-ledger
  mkdir -p "$RESULT_DIR/preflight"
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" validate_release_ledger "$BUS_GATE2_RELEASE_LEDGER" "$TUPLE_FORMAT" || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  run_g1
  if [ "$CASE_ID" = "T65" ]; then
    [ "$ROLE" != "parent-fail" ] || die "parent-fail role unexpectedly passed every gate"
    if [ "$PLAN_MODE" = "1" ]; then
      write_final_result plan
      printf 'Browser Product Gate 2 harness plan OK: %s\n' "$RESULT_DIR"
    else
      write_final_result candidate-pass
      printf 'Browser Product Gate 2 candidate harness OK: %s\n' "$RESULT_DIR"
    fi
    return
  fi

  mkdir -p "$RESULT_DIR/native"
  gate=g2-boot
  gate_argv_at "$BUS_GATE2_BUS_ENGINE_OS_ROOT" "$gate" "$RESULT_DIR/native" bash scripts/bus-boot-test --target-arch riscv64 --kernel "$BUS_GATE2_KERNEL" --disk-image "$BUS_GATE2_ROOTFS" --serial-log "$RESULT_DIR/native/serial.log" --report "$RESULT_DIR/native/boot.json" --no-network --expect 'Reached target Multi-User System.' --expect 'bus-engine-os login:' --timeout 600 --settle-seconds 5 --append 'console=ttyS0 root=/dev/vda rw' --qemu-arg -device --qemu-arg virtio-rng-device || finish_parent_failure "$gate" "$RESULT_DIR/native/${gate}.stderr"
  gate=g2-check-boot
  gate_argv_at "$BUS_GATE2_BUS_ENGINE_OS_ROOT" "$gate" "$RESULT_DIR/native" python3 scripts/bus-check-boot-test-report --report "$RESULT_DIR/native/boot.json" --serial-log "$RESULT_DIR/native/serial.log" --kernel "$BUS_GATE2_KERNEL" --disk-image "$BUS_GATE2_ROOTFS" --target-arch riscv64 --append 'console=ttyS0 root=/dev/vda rw' --expect 'Reached target Multi-User System.' --expect 'bus-engine-os login:' || finish_parent_failure "$gate" "$RESULT_DIR/native/${gate}.stderr"
  require_artifact BUS_GATE2_KERNEL BUS_GATE2_KERNEL_SIZE BUS_GATE2_KERNEL_SHA256
  require_artifact BUS_GATE2_ROOTFS BUS_GATE2_ROOTFS_SIZE BUS_GATE2_ROOTFS_SHA256

  gate=g3-release
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" "$BUS_GATE2_BUS_ENGINE_OS_ROOT/scripts/bus-check-browser-hosted-release" --dir "$BUS_GATE2_BUNDLE_DIR" --profile virtual-server --summary-out "$RESULT_DIR/preflight/release-summary.json" || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  gate=g3-codex-package-release-provenance
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" validate_codex_package_reports || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  gate=g3-bundle-kernel-enablement
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" validate_bundle_kernel_enablement || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  gate=g3-sha256sums
  gate_argv_at "$BUS_GATE2_BUNDLE_DIR" "$gate" "$RESULT_DIR/preflight" sha256sum -c SHA256SUMS || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  gate=g3-docker-image-inspect
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" docker image inspect "$BUS_GATE2_CHROMIUM_TAG" || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  if [ "$PLAN_MODE" != "1" ]; then
    python3 - "$RESULT_DIR/preflight/${gate}.stdout" "$BUS_GATE2_BROWSER_IMAGE_ID" <<'PY' || finish_parent_failure g3-docker-image-id "$RESULT_DIR/preflight/${gate}.stderr"
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
want = sys.argv[2]
if not doc or doc[0].get("Id") != want:
    raise SystemExit("docker image ID mismatch")
PY
  fi
  gate=g3-cdp-parser-fixture
  gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$RESULT_DIR/preflight" node scripts/ci/wasm-browser-cdp-gate-test.mjs || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"
  cat >"$RESULT_DIR/preflight/tuple-inputs.json" <<EOF
{"gate":{"path":"scripts/ci/wasm-browser-cdp-gate.mjs","sha256":"$(sha256_file "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-gate.mjs")"},"test":{"path":"scripts/ci/wasm-browser-cdp-gate-test.mjs","sha256":"$(sha256_file "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-gate-test.mjs")"},"proof_gate":{"path":"scripts/ci/wasm-browser-cdp-proof-gate.mjs","sha256":"$(sha256_file "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-proof-gate.mjs")"},"proof_test":{"path":"scripts/ci/wasm-browser-cdp-proof-gate-test.mjs","sha256":"$(sha256_file "$BUS_GATE2_QEMU_ROOT/scripts/ci/wasm-browser-cdp-proof-gate-test.mjs")"}}
EOF

  gate=g3-heavy-lock-non-overlap
  gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/preflight" validate_heavy_lock_non_overlap || finish_parent_failure "$gate" "$RESULT_DIR/preflight/${gate}.stderr"

  mkdir -p "$RESULT_DIR/chromium"
  gate=g4-chromium
  G4_STARTED=1
  if [ "$CASE_ID" = "composed" ]; then
    gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/chromium" timeout 1260s docker run --rm --name "$BUS_GATE2_G4_CONTAINER_NAME" --label "bus.thread=42" --label "bus.evidence=$TUPLE_FORMAT" --network bridge --user 1000:1000 --cap-add SYS_ADMIN --read-only --tmpfs /tmp:rw,nosuid,nodev,size=1g --shm-size 1g --workdir /workspace --mount type=bind,src="$BUS_GATE2_QEMU_ROOT",dst=/workspace,readonly --mount type=bind,src="$BUS_GATE2_BUNDLE_DIR",dst=/bundle,readonly --mount type=bind,src="$RESULT_DIR/chromium",dst=/out "$BUS_GATE2_BROWSER_IMAGE_ID" node scripts/ci/wasm-browser-cdp-gate.mjs --artifact-dir /bundle/artifacts --guest-manifest /bundle/browser-hosted-manifest.json --firmware-dir /bundle/firmware --kernel /bundle/guest/kernel --rootfs /bundle/guest/rootfs.raw --target-arch riscv64 --machine virt --memory 512M --rootfs-device virtio-mmio --network none --marker 'bus-engine-os login:' --expect-text 'QEMU_WASM_SERVICE_READY' --expect-text 'bus-engine-os-browser-http-proof: http-ok' --expect-text "$BUS_GATE2_STORAGE_MARKER" --service-request-operation initialize --service-request-timeout-ms 10000 --timeout-ms 1200000 --max-output-bytes 4000000 --host 127.0.0.1 --port 8160 --cdp-port 9222 --chrome /usr/bin/chromium --qemu-arg -device --qemu-arg virtio-rng-device --out /out/result.json || finish_parent_failure "$gate" "$RESULT_DIR/chromium/${gate}.stderr"
  else
    gate_argv_at "$ROOT_DIR" "$gate" "$RESULT_DIR/chromium" timeout 1260s docker run --rm --name "$BUS_GATE2_G4_CONTAINER_NAME" --label "bus.thread=42" --label "bus.evidence=$TUPLE_FORMAT" --network bridge --user 1000:1000 --cap-add SYS_ADMIN --read-only --tmpfs /tmp:rw,nosuid,nodev,size=1g --shm-size 1g --workdir /workspace --mount type=bind,src="$BUS_GATE2_QEMU_ROOT",dst=/workspace,readonly --mount type=bind,src="$BUS_GATE2_BUNDLE_DIR",dst=/bundle,readonly --mount type=bind,src="$RESULT_DIR/chromium",dst=/out "$BUS_GATE2_BROWSER_IMAGE_ID" node scripts/ci/wasm-browser-cdp-gate.mjs --artifact-dir /bundle/artifacts --guest-manifest /bundle/browser-hosted-manifest.json --firmware-dir /bundle/firmware --kernel /bundle/guest/kernel --rootfs /bundle/guest/rootfs.raw --target-arch riscv64 --machine virt --memory 512M --rootfs-device virtio-mmio --network none --marker 'bus-engine-os login:' --expect-text 'QEMU_WASM_SNAPSHOT_RELEASED' --expect-text 'bus-engine-os-first-resume-identity: identity-evidence' --expect-text 'QEMU_WASM_SERVICE_READY' --expect-text 'bus-engine-os-browser-http-proof: http-ok' --expect-text "$BUS_GATE2_STORAGE_MARKER" --serial-input-after-text 'QEMU_WASM_SNAPSHOT_READY' --serial-input-text $'QEMU_WASM_RESUME_CONTINUE\n' --pre-serial-input-wait-ms 500 --service-request-operation initialize --service-request-timeout-ms 10000 --timeout-ms 1200000 --max-output-bytes 4000000 --host 127.0.0.1 --port 8160 --cdp-port 9222 --chrome /usr/bin/chromium --qemu-arg -device --qemu-arg virtio-rng-device --out /out/result.json || finish_parent_failure "$gate" "$RESULT_DIR/chromium/${gate}.stderr"
  fi
  cleanup_g4
  G4_STARTED=0
  gate=g4-generated-exec-proof
  gate_argv_at "$BUS_GATE2_QEMU_ROOT" "$gate" "$RESULT_DIR/chromium" node scripts/ci/wasm-browser-cdp-proof-gate.mjs --result "$RESULT_DIR/chromium/result.json" --require-generated-exec --require-guest-manifest --require-service-roundtrip initialize --require-success --max-elapsed-ms 1200000 --json || finish_parent_failure "$gate" "$RESULT_DIR/chromium/${gate}.stderr"
  [ "$ROLE" != "parent-fail" ] || die "parent-fail role unexpectedly passed every gate"
  if [ "$PLAN_MODE" = "1" ]; then
    write_final_result plan
    printf 'Browser Product Gate 2 harness plan OK: %s\n' "$RESULT_DIR"
    return
  fi
  write_tuple_from_result "$RESULT_DIR/chromium"
  write_final_result candidate-pass
  printf 'Browser Product Gate 2 candidate harness OK: %s\n' "$RESULT_DIR"
}

assert_fail() {
  local want=$1
  shift
  local out="$SELF_TMP/assert.out"
  if ( "$@" ) >"$out" 2>&1; then
    printf 'expected failure containing %s\n' "$want" >&2
    exit 1
  fi
  grep -F "$want" "$out" >/dev/null || { printf 'missing expected failure %s in:\n' "$want" >&2; cat "$out" >&2; exit 1; }
}

self_write_file() { printf '%s' "$2" >"$1"; }

self_export_artifact() {
  local var=$1 path=$2
  eval "BUS_GATE2_${var}=\$path"
  eval "BUS_GATE2_${var}_SIZE=\$(file_size \"\$path\")"
  eval "BUS_GATE2_${var}_SHA256=\$(sha256_file \"\$path\")"
  export "BUS_GATE2_${var}" "BUS_GATE2_${var}_SIZE" "BUS_GATE2_${var}_SHA256"
}

self_export_bundle() {
  local path=$1 identity
  identity=$(bundle_identity "$path")
  BUS_GATE2_BUNDLE_DIR=$path
  BUS_GATE2_BUNDLE_DIR_SIZE=${identity%%$'\t'*}
  BUS_GATE2_BUNDLE_DIR_SHA256=${identity#*$'\t'}
  export BUS_GATE2_BUNDLE_DIR BUS_GATE2_BUNDLE_DIR_SIZE BUS_GATE2_BUNDLE_DIR_SHA256
}

self_init_repo() {
  local dir=$1
  local file=$2
  local content=$3
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email selftest@example.invalid
  git -C "$dir" config user.name "Gate2 Self Test"
  self_write_file "$dir/$file" "$content"
  git -C "$dir" add "$file"
  git -C "$dir" commit -q -m "initial"
}

self_prepare_public_harness() {
  local destination=$1 source=$2
  [ "$destination" = "$source" ] || cp "$source" "$destination"
  python3 - "$destination" "$h1" "$h3" "$h4" "$h5" "$h6" "$h7" "$h8" "$h9" "$h10" "$h11" "$QEMU_COMPILED_JS_SHA256" "$QEMU_COMPILED_WASM_SHA256" <<'PY'
import sys

path, h1, h3, h4, h5, h6, h7, h8, h9, h10, h11, js_sha, wasm_sha = sys.argv[1:]
updates = {
    "QEMU_COMPILED_SOURCE_COMMIT": h11,
    "QEMU_COMPILED_JS_SHA256": js_sha,
    "QEMU_COMPILED_WASM_SHA256": wasm_sha,
    "ROLE_T50_PARENT": h4,
    "ROLE_T50_CANDIDATE": h5,
    "ROLE_T64_PARENT": h6,
    "ROLE_T64_CANDIDATE": h7,
    "ROLE_T65_PARENT": h8,
    "ROLE_T65_CANDIDATE": h9,
    "ROLE_T154_PARENT": h8,
    "ROLE_T154_CANDIDATE": h10,
    "ROLE_T66_TIP": h1,
}
seen = set()
result = []
for line in open(path, encoding="utf-8"):
    for key, value in updates.items():
        if key not in seen and line.startswith(f"{key}="):
            line = f"{key}={value}\n"
            seen.add(key)
            break
    result.append(line)
if seen != set(updates):
    missing = sorted(set(updates) - seen)
    raise SystemExit(f"public harness role patch missed: {missing}")
with open(path, "w", encoding="utf-8") as handle:
    handle.writelines(result)
PY
  chmod 0755 "$destination"
}

self_test() {
  SELF_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bus-gate2-selftest.XXXXXX")
  export SELF_TMP
  trap 'rm -rf "$SELF_TMP"' RETURN
  TMPDIR=$SELF_TMP
  export TMPDIR
  local harness_root=$ROOT_DIR artifact_dir="$SELF_TMP/artifacts" busdk_root="$SELF_TMP/busdk" qemu_root="$SELF_TMP/qemu" os_root="$SELF_TMP/beo" codex_root="$SELF_TMP/codex" out="$SELF_TMP/out"
  local heavy_lock_dir="$SELF_TMP/busdk-worker-guard-$(id -u)" heavy_lock_fd heavy_lock_path heavy_lock_readback wrong_lock_fd
  local busdk_t50_parent_commit busdk_t50_candidate_commit busdk_t64_candidate_commit busdk_composed_commit
  local h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12
  local empty_sha collision_name collision_one collision_two collision_two_identity
  local release_ledger_json health_key
  self_init_repo "$os_root" README.md "beo-t50-parent"
  h4=$(git -C "$os_root" rev-parse HEAD)
  self_write_file "$os_root/t50-candidate.txt" "beo-t50-candidate"
  git -C "$os_root" add t50-candidate.txt
  git -C "$os_root" commit -q -m "t50 candidate"
  h5=$(git -C "$os_root" rev-parse HEAD)
  self_write_file "$os_root/t64-parent.txt" "beo-t64-parent"
  git -C "$os_root" add t64-parent.txt
  git -C "$os_root" commit -q -m "t64 parent"
  h6=$(git -C "$os_root" rev-parse HEAD)
  self_write_file "$os_root/t64-candidate.txt" "beo-t64-candidate"
  git -C "$os_root" add t64-candidate.txt
  git -C "$os_root" commit -q -m "t64 candidate"
  h7=$(git -C "$os_root" rev-parse HEAD)
  self_write_file "$os_root/t66-tip.txt" "beo-t66-tip"
  git -C "$os_root" add t66-tip.txt
  git -C "$os_root" commit -q -m "t66 dependency"
  h1=$(git -C "$os_root" rev-parse HEAD)
  self_init_repo "$qemu_root" README.md "qemu-t65-parent"
  mkdir -p "$qemu_root/chardev" "$qemu_root/scripts/ci"
  self_write_file "$qemu_root/chardev/char-wasm.c" "legacy pending input"
  git -C "$qemu_root" add chardev/char-wasm.c
  git -C "$qemu_root" commit -q -m "t65 parent source"
  h8=$(git -C "$qemu_root" rev-parse HEAD)
  self_write_file "$qemu_root/chardev/char-wasm.c" "uint64_t pending_input_token;"
  self_write_file "$qemu_root/scripts/ci/wasm-chardev-emscripten-abi-test.mjs" 'import assert from "node:assert/strict"; import { readFileSync } from "node:fs"; const source = readFileSync(`${process.env.QEMU_TEST_ROOT}/chardev/char-wasm.c`, "utf8"); assert.ok(source.includes("pending_input_token"), "production source must provide pending_input_token"); console.log("wasm-chardev-emscripten-abi-test: ok");'
  self_write_file "$qemu_root/scripts/ci/wasm-chardev-startup-guard-test.mjs" 'import assert from "node:assert/strict"; import { readFileSync } from "node:fs"; const source = readFileSync(`${process.env.QEMU_TEST_ROOT}/chardev/char-wasm.c`, "utf8"); assert.ok(source.includes("pending_input_token")); console.log("wasm chardev startup guard contract: PASS");'
  self_write_file "$qemu_root/scripts/ci/wasm-build-smoke-initramfs-test.py" 'import os; from pathlib import Path; assert "pending_input_token" in (Path(os.environ["QEMU_TEST_ROOT"]) / "chardev/char-wasm.c").read_text(); print("wasm-build-smoke-initramfs-test: ok")'
  git -C "$qemu_root" add chardev/char-wasm.c scripts/ci
  git -C "$qemu_root" commit -q -m "t65 candidate"
  h9=$(git -C "$qemu_root" rev-parse HEAD)
  git -C "$qemu_root" checkout -q "$h8"
  self_write_file "$qemu_root/t154-candidate.txt" "qemu-t154-candidate"
  git -C "$qemu_root" add t154-candidate.txt
  git -C "$qemu_root" commit -q -m "t154 candidate"
  h10=$(git -C "$qemu_root" rev-parse HEAD)
  git -C "$qemu_root" checkout -q "$h9"
  git -C "$qemu_root" merge -q --no-ff "$h10" -m "qemu composed"
  for f in wasm-browser-smoke-args-test.mjs wasm-browser-smoke-runner-test.mjs wasm-guest-manifest-test.mjs; do
    self_write_file "$qemu_root/scripts/ci/$f" "console.log('ok')"
  done
  self_write_file "$qemu_root/scripts/ci/wasm-prepare-tuxboot-smoke-guest-test.py" "print('ok')"
  git -C "$qemu_root" add scripts/ci
  git -C "$qemu_root" commit -q -m "compiled QEMU composition"
  h11=$(git -C "$qemu_root" rev-parse HEAD)
  for f in wasm-browser-cdp-gate-test.mjs wasm-browser-cdp-gate.mjs wasm-browser-cdp-proof-gate-test.mjs wasm-browser-cdp-proof-gate.mjs; do
    self_write_file "$qemu_root/scripts/ci/$f" "--qemu-arg --service-request-operation --service-request-timeout-ms --require-service-roundtrip"
  done
  git -C "$qemu_root" add scripts/ci
  git -C "$qemu_root" commit -q -m "host runtime gate candidate"
  h12=$(git -C "$qemu_root" rev-parse HEAD)
  h2=$h12
  [ "$h8" != "$h9" ] && [ "$h9" != "$h11" ] && [ "$h11" != "$h12" ] ||
    die "T65, compiled QEMU, and host runtime identities must be distinct"
  git -C "$qemu_root" merge-base --is-ancestor "$h8" "$h9" ||
    die "synthetic T65 parent must be an ancestor of its candidate"
  git -C "$qemu_root" merge-base --is-ancestor "$h9" "$h11" ||
    die "synthetic compiled QEMU must contain the T65 candidate"
  git -C "$qemu_root" merge-base --is-ancestor "$h11" "$h12" ||
    die "synthetic host runtime must be based on compiled QEMU"
  if git -C "$qemu_root" merge-base --is-ancestor "$h11" "$h9"; then
    die "synthetic standalone T65 candidate unexpectedly contains compiled QEMU"
  fi
  self_init_repo "$codex_root" README.md "codex"
  h3=$(git -C "$codex_root" rev-parse HEAD)
  ROLE_T50_PARENT=$h4 ROLE_T50_CANDIDATE=$h5
  ROLE_T64_PARENT=$h6 ROLE_T64_CANDIDATE=$h7
  ROLE_T65_PARENT=$h8 ROLE_T65_CANDIDATE=$h9
  ROLE_T154_PARENT=$h8 ROLE_T154_CANDIDATE=$h10
  ROLE_T66_TIP=$h1
  ROLE_T50_PARENT_FAIL_GATE=g2-boot
  ROLE_T50_PARENT_FAIL_PREDICATE='bus-engine-os login:'
  ROLE_T65_PARENT_FAIL_GATE=g1-qemu-wasm-chardev-emscripten-abi-test
  ROLE_T65_PARENT_FAIL_PREDICATE='production source must provide pending_input_token'
  mkdir -p "$busdk_root"
  git -C "$busdk_root" init -q
  git -C "$busdk_root" config user.email selftest@example.invalid
  git -C "$busdk_root" config user.name "Gate2 Self Test"
  self_write_file "$busdk_root/README.md" "busdk"
  git -C "$busdk_root" add README.md
  git -C "$busdk_root" update-index --add --cacheinfo "160000,$h4,bus-engine-os"
  git -C "$busdk_root" commit -q -m "busdk t50 parent gitlink"
  busdk_t50_parent_commit=$(git -C "$busdk_root" rev-parse HEAD)
  git -C "$busdk_root" update-index --add --cacheinfo "160000,$h5,bus-engine-os"
  git -C "$busdk_root" commit -q -m "busdk t50 candidate gitlink"
  busdk_t50_candidate_commit=$(git -C "$busdk_root" rev-parse HEAD)
  git -C "$busdk_root" update-index --add --cacheinfo "160000,$h7,bus-engine-os"
  git -C "$busdk_root" commit -q -m "busdk t64 candidate gitlink"
  busdk_t64_candidate_commit=$(git -C "$busdk_root" rev-parse HEAD)
  git -C "$busdk_root" update-index --add --cacheinfo "160000,$h1,bus-engine-os"
  git -C "$busdk_root" commit -q -m "busdk composed gitlink"
  busdk_composed_commit=$(git -C "$busdk_root" rev-parse HEAD)
  ROOT_DIR=$busdk_root
  git -C "$os_root" checkout -q "$h1"
  git -C "$qemu_root" checkout -q "$h12"
  git -C "$busdk_root" checkout -q "$busdk_composed_commit"
  mkdir -p "$artifact_dir" "$qemu_root/scripts/ci" "$os_root/scripts" "$codex_root" "$artifact_dir/bundle"
  for f in kernel rootfs qemu.js qemu.wasm serial.txt; do self_write_file "$artifact_dir/$f" "$f"; done
  cat >"$artifact_dir/ledger.json" <<'EOF'
{"format":"bus-engine-os-chromium-vertical-slice-evidence-v1","containment":true,"ordered_down":true,"zero_survivors":true,"truthful_telemetry":true,"control_api_responsive":true,"supervisor_accepted":true}
EOF
  self_write_file "$artifact_dir/bundle/SHA256SUMS" "sums"
  for f in bus-boot-test bus-check-boot-test-report bus-check-browser-hosted-release; do self_write_file "$os_root/scripts/$f" "$f"; done
  QEMU_COMPILED_SOURCE_COMMIT=$h11
  QEMU_COMPILED_JS_SHA256=$(sha256_file "$artifact_dir/qemu.js")
  QEMU_COMPILED_WASM_SHA256=$(sha256_file "$artifact_dir/qemu.wasm")
  cat >"$artifact_dir/export.json" <<EOF
{"format":"bus-engine-os-browser-hosted-bundle-v1","default_parameters":{"kernelAppend":"console=ttyS0 root=/dev/vda rw bus.engine.codex_app_server=1"},"files":[{"role":"qemu-javascript","sha256":"$QEMU_COMPILED_JS_SHA256"},{"role":"qemu-wasm","sha256":"$QEMU_COMPILED_WASM_SHA256"}]}
EOF
  local package_id=codex-app-server-0.144.0-1.riscv64
  local package_root="$SELF_TMP/package-root" package_archive="$artifact_dir/$package_id.buspkg.tar.gz"
  mkdir -p "$package_root/root/usr/bin" "$package_root/root/usr/lib/codex-app-server/bin"
  self_write_file "$package_root/root/usr/lib/codex-app-server/bin/codex-app-server" "codex-app-server-binary"
  ln -s ../lib/codex-app-server/bin/codex-app-server "$package_root/root/usr/bin/codex-app-server"
  tar -czf "$package_archive" -C "$package_root" \
    root/usr/bin/codex-app-server root/usr/lib/codex-app-server/bin/codex-app-server
  local package_archive_sha package_binary_sha
  package_archive_sha=$(sha256_file "$package_archive")
  package_binary_sha=$(sha256_file "$package_root/root/usr/lib/codex-app-server/bin/codex-app-server")
  cat >"$artifact_dir/package.json" <<EOF
{"format":"thread64-package-import-e2e-result-v1","result":"PASS","package":{"id":"$package_id","archive_sha256":"$package_archive_sha","binary_sha256":"$package_binary_sha","retained_archive":"$package_archive"}}
EOF
  cat >"$artifact_dir/release.json" <<EOF
{"format":"bus-engine-os-image-acceptance-v1","status":"accepted-evidence","target_arch":"riscv64","git_commit":"$h1","provenance":"build-provenance.json","image_profile":{"kernel_profile":"virtual-server","package_groups":["app-server-bridge-runtime"]}}
EOF
  cat >"$artifact_dir/build-provenance.json" <<EOF
{"format":"bus-engine-os-release-metadata-v1","package_set":[{"id":"$package_id","name":"codex-app-server","architecture":"riscv64","runtime":true,"sha256":"$package_archive_sha"}]}
EOF

  BUS_GATE2_BUSDK_COMMIT=$busdk_composed_commit
  BUS_GATE2_BUS_ENGINE_OS_ROOT=$os_root BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h1 BUS_GATE2_BUS_ENGINE_OS_SUBMODULE_PATH=bus-engine-os
  BUS_GATE2_QEMU_ROOT=$qemu_root BUS_GATE2_QEMU_COMMIT=$h2
  BUS_GATE2_OPENAI_CODEX_ROOT=$codex_root BUS_GATE2_OPENAI_CODEX_COMMIT=$h3
  BUS_GATE2_T50_PARENT_COMMIT=$h4 BUS_GATE2_T50_CANDIDATE_COMMIT=$h5 BUS_GATE2_T64_PARENT_COMMIT=$h6 BUS_GATE2_T64_CANDIDATE_COMMIT=$h7
  BUS_GATE2_T65_PARENT_COMMIT=$h8 BUS_GATE2_T65_CANDIDATE_COMMIT=$h9 BUS_GATE2_T154_PARENT_COMMIT=$h8 BUS_GATE2_T154_CANDIDATE_COMMIT=$h10 BUS_GATE2_T66_TIP_COMMIT=$h1
  BUS_GATE2_ACTIVE_SOURCE_OWNER=bus_engine_os BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  BUS_GATE2_BROWSER_IMAGE_ID=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb BUS_GATE2_CHROMIUM_TAG=qemu/wasm-browser:node22-bookworm
  BUS_GATE2_RELEASE_LEDGER=$artifact_dir/ledger.json
  mkdir -m 0700 "$heavy_lock_dir"
  heavy_lock_path=$heavy_lock_dir/heavy.lock
  : >"$heavy_lock_path"
  chmod 0600 "$heavy_lock_path"
  exec {heavy_lock_fd}<>"$heavy_lock_path"
  flock --exclusive --nonblock "$heavy_lock_fd"
  BUS_GATE2_HEAVY_LOCK_FD=$heavy_lock_fd
  self_export_bundle "$artifact_dir/bundle"
  empty_sha=$(sha256_text "")
  collision_name=$'a\n'"$empty_sha"'  b'
  collision_one="$SELF_TMP/collision-one"
  collision_two="$SELF_TMP/collision-two"
  mkdir -p "$collision_one" "$collision_two"
  self_write_file "$collision_one/$collision_name" payload
  self_write_file "$collision_two/a" payload
  self_write_file "$collision_two/b" ""
  assert_fail "bundle path contains newline" bundle_identity "$collision_one"
  collision_two_identity=$(bundle_identity "$collision_two")
  [ -n "$collision_two_identity" ] || die "non-delimited bundle identity missing"
  BUS_GATE2_G4_CONTAINER_NAME=bus-gate2-selftest BUS_GATE2_STORAGE_MARKER=storage-marker BUS_GATE2_G4_SERIAL_INPUT_FILE=$artifact_dir/serial.txt BUS_GATE2_G4_SERIAL_INPUT_SHA256=$(sha256_file "$artifact_dir/serial.txt")
  export BUS_GATE2_BUSDK_COMMIT BUS_GATE2_BUS_ENGINE_OS_ROOT BUS_GATE2_BUS_ENGINE_OS_COMMIT BUS_GATE2_BUS_ENGINE_OS_SUBMODULE_PATH BUS_GATE2_QEMU_ROOT BUS_GATE2_QEMU_COMMIT BUS_GATE2_OPENAI_CODEX_ROOT BUS_GATE2_OPENAI_CODEX_COMMIT
  export BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT BUS_GATE2_T64_PARENT_COMMIT BUS_GATE2_T64_CANDIDATE_COMMIT BUS_GATE2_T65_PARENT_COMMIT BUS_GATE2_T65_CANDIDATE_COMMIT BUS_GATE2_T154_PARENT_COMMIT BUS_GATE2_T154_CANDIDATE_COMMIT BUS_GATE2_T66_TIP_COMMIT BUS_GATE2_ACTIVE_SOURCE_OWNER BUS_GATE2_ACTIVE_SOURCE_COMMIT
  export BUS_GATE2_BROWSER_IMAGE_ID BUS_GATE2_CHROMIUM_TAG BUS_GATE2_RELEASE_LEDGER BUS_GATE2_HEAVY_LOCK_FD BUS_GATE2_BUNDLE_DIR BUS_GATE2_BUNDLE_DIR_SIZE BUS_GATE2_BUNDLE_DIR_SHA256 BUS_GATE2_G4_CONTAINER_NAME BUS_GATE2_STORAGE_MARKER BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256
  self_export_artifact KERNEL "$artifact_dir/kernel"; self_export_artifact ROOTFS "$artifact_dir/rootfs"; self_export_artifact RESOLVER "$artifact_dir/package.json"; self_export_artifact QEMU_JS "$artifact_dir/qemu.js"; self_export_artifact QEMU_WASM "$artifact_dir/qemu.wasm"
  self_export_artifact EXPORT_MANIFEST "$artifact_dir/export.json"; self_export_artifact SHA256SUMS "$artifact_dir/bundle/SHA256SUMS"; self_export_artifact PACKAGE_REPORT "$artifact_dir/package.json"; self_export_artifact RELEASE_REPORT "$artifact_dir/release.json"
  CASE_ID=composed
  ROLE=candidate-pass
  RESULT_DIR=$out
  PLAN_MODE=1
  unset BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256
  validate_role
  validate_identity_inputs
  local saved_heavy_lock_fd=$BUS_GATE2_HEAVY_LOCK_FD
  unset BUS_GATE2_HEAVY_LOCK_FD
  assert_fail "missing required field: BUS_GATE2_HEAVY_LOCK_FD" validate_heavy_lock_non_overlap
  BUS_GATE2_HEAVY_LOCK_FD=$saved_heavy_lock_fd
  export BUS_GATE2_HEAVY_LOCK_FD
  : >"$SELF_TMP/wrong-heavy.lock"
  chmod 0600 "$SELF_TMP/wrong-heavy.lock"
  exec {wrong_lock_fd}<>"$SELF_TMP/wrong-heavy.lock"
  BUS_GATE2_HEAVY_LOCK_FD=$wrong_lock_fd assert_fail "heavy lock fd path mismatch" validate_heavy_lock_non_overlap
  flock --unlock "$heavy_lock_fd"
  assert_fail "heavy lock non-overlap is false" validate_heavy_lock_non_overlap
  flock --exclusive --nonblock "$heavy_lock_fd"
  heavy_lock_readback=$(validate_heavy_lock_non_overlap)
  [ "$heavy_lock_readback" = $'heavy_lock_path='"$heavy_lock_path"$'\nheavy_lock_owner_uid='"$(id -u)"$'\nheavy_lock_fd='"$heavy_lock_fd"$'\nheavy_lock_non_overlap=true' ] || die "heavy lock readback mismatch"
  local bundle_sha=$BUS_GATE2_BUNDLE_DIR_SHA256
  BUS_GATE2_BUNDLE_DIR_SHA256=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc assert_fail "BUS_GATE2_BUNDLE_DIR_SHA256 mismatch" validate_identity_inputs
  BUS_GATE2_BUNDLE_DIR_SHA256=$bundle_sha
  validate_identity_inputs
  validate_bundle_kernel_enablement >/dev/null
  cp "$BUS_GATE2_EXPORT_MANIFEST" "$SELF_TMP/export.base.json"
  python3 - "$BUS_GATE2_EXPORT_MANIFEST" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path, encoding="utf-8"))
doc["default_parameters"]["kernelAppend"] = "console=ttyS0 root=/dev/vda rw"
json.dump(doc, open(path, "w", encoding="utf-8"))
PY
  assert_fail "exactly one bus.engine.codex_app_server=1" validate_bundle_kernel_enablement
  cp "$SELF_TMP/export.base.json" "$BUS_GATE2_EXPORT_MANIFEST"
  validate_codex_package_reports >/dev/null
  cp "$BUS_GATE2_PACKAGE_REPORT" "$SELF_TMP/package.base.json"
  python3 - "$BUS_GATE2_PACKAGE_REPORT" <<'PY'
import json, sys
path = sys.argv[1]
doc = json.load(open(path, encoding="utf-8"))
doc["package"]["binary_sha256"] = "missing"
json.dump(doc, open(path, "w", encoding="utf-8"))
PY
  assert_fail "binary SHA-256" validate_codex_package_reports
  cp "$SELF_TMP/package.base.json" "$BUS_GATE2_PACKAGE_REPORT"

  BUS_GATE2_T50_PARENT_COMMIT=$h4
  BUS_GATE2_T50_CANDIDATE_COMMIT=$h5
  BUS_GATE2_G4_SERIAL_INPUT_FILE=$artifact_dir/serial.txt
  BUS_GATE2_G4_SERIAL_INPUT_SHA256=$(sha256_file "$artifact_dir/serial.txt")
  export BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256
  git -C "$qemu_root" checkout -q "$h9"
  BUS_GATE2_QEMU_COMMIT=$h9
  QEMU_COMPILED_SOURCE_COMMIT=$h11
  assert_fail "QEMU host gate candidate is not based on compiled artifact source" validate_qemu_host_only_range

  git -C "$qemu_root" checkout -q "$h8"
  BUS_GATE2_QEMU_COMMIT=$h8
  BUS_GATE2_ACTIVE_SOURCE_OWNER=qemu
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h8
  CASE_ID=T65
  ROLE=parent-fail
  EXPECTED_FAIL_GATE=$ROLE_T65_PARENT_FAIL_GATE
  EXPECTED_FAIL_PREDICATE=$ROLE_T65_PARENT_FAIL_PREDICATE
  RESULT_DIR=$SELF_TMP/t65-parent
  PLAN_MODE=0
  validate_role
  validate_identity_inputs
  require_packet_paths
  mkdir -p "$RESULT_DIR"
  : >"$RESULT_DIR/status.tsv"
  printf 'cleanup_policy=exact-container-name-and-labels\n' >"$RESULT_DIR/cleanup.log"
  ( run_g1 )
  grep -F '"observed_classification":"parent-fail"' "$RESULT_DIR/final-result.json" >/dev/null

  git -C "$qemu_root" checkout -q "$h9"
  BUS_GATE2_QEMU_COMMIT=$h9
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h9
  ROLE=candidate-pass
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  RESULT_DIR=$SELF_TMP/t65-candidate
  validate_role
  validate_identity_inputs
  require_packet_paths
  mkdir -p "$RESULT_DIR"
  : >"$RESULT_DIR/status.tsv"
  run_g1
  python3 - "$RESULT_DIR/status.tsv" <<'PY'
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    records = [line.rstrip("\n").split("\t") for line in handle]
want = [
    "g1-qemu-wasm-chardev-emscripten-abi-test",
    "g1-qemu-wasm-chardev-startup-guard-test",
    "g1-qemu-wasm-build-smoke-initramfs-test",
]
if [record[0] for record in records] != want:
    raise SystemExit(f"standalone T65 ran wrong gates: {records!r}")
if any(len(record) < 2 or record[1] != "0" for record in records):
    raise SystemExit(f"standalone T65 candidate did not pass all gates: {records!r}")
PY

  local t65_public_dir="$SELF_TMP/t65-public-flow"
  local t65_harness_dir="$busdk_root/tests/superproject"
  local t65_candidate_harness="$t65_harness_dir/t65-candidate-harness.sh"
  local t65_parent_harness="$t65_harness_dir/t65-parent-harness.sh"
  local t65_candidate_result="$t65_public_dir/candidate-result"
  local t65_parent_result="$t65_public_dir/parent-result"
  mkdir -p "$t65_public_dir" "$t65_harness_dir"
  self_write_file "$os_root/scripts/bus-boot-test" $'#!/usr/bin/env bash\nprintf "T65_PUBLIC_G2_BOOT_ACTION\\n" >&2\nexit 42\n'
  chmod 0755 "$os_root/scripts/bus-boot-test"
  self_prepare_public_harness "$t65_candidate_harness" "$harness_root/tests/superproject/test_browser_virtual_server_gate2_e2e.sh"
  git -C "$harness_root" show ca902aa27da75567eb8c4f67ce12c43e9c0dba57:tests/superproject/test_browser_virtual_server_gate2_e2e.sh >"$t65_parent_harness"
  self_prepare_public_harness "$t65_parent_harness" "$t65_parent_harness"
  if ! bash "$t65_candidate_harness" --case T65 --role candidate-pass --result-dir "$t65_candidate_result" >"$t65_public_dir/candidate.stdout" 2>"$t65_public_dir/candidate.stderr"; then
    cat "$t65_public_dir/candidate.stderr" >&2
    die "T65 public candidate flow did not terminate after G1"
  fi
  if bash "$t65_parent_harness" --case T65 --role candidate-pass --result-dir "$t65_parent_result" >"$t65_public_dir/parent.stdout" 2>"$t65_public_dir/parent.stderr"; then
    die "T65 parent control unexpectedly passed"
  fi
  python3 - "$t65_candidate_result" "$t65_parent_result" <<'PY'
import json
from pathlib import Path
import sys

candidate, parent = map(Path, sys.argv[1:])
g1 = [
    "g1-qemu-wasm-chardev-emscripten-abi-test",
    "g1-qemu-wasm-chardev-startup-guard-test",
    "g1-qemu-wasm-build-smoke-initramfs-test",
]

def gates(root):
    return [line.split("\t", 1)[0] for line in (root / "status.tsv").read_text(encoding="utf-8").splitlines()]

candidate_gates = gates(candidate)
if candidate_gates != ["g0-release-ledger", *g1]:
    raise SystemExit(f"T65 public candidate ran wrong gates: {candidate_gates!r}")
with (candidate / "final-result.json").open(encoding="utf-8") as handle:
    final = json.load(handle)
if final.get("observed_classification") != "candidate-pass":
    raise SystemExit(f"T65 public candidate final result is wrong: {final!r}")
if any(gate.startswith(("g2-", "g3-", "g4-")) for gate in candidate_gates):
    raise SystemExit(f"T65 public candidate entered a later gate: {candidate_gates!r}")
if (candidate / "native").exists() or (candidate / "chromium").exists():
    raise SystemExit("T65 public candidate created a later-gate result directory")
if "T65_PUBLIC_G2_BOOT_ACTION" in "\n".join(
    path.read_text(encoding="utf-8", errors="replace")
    for path in candidate.rglob("*") if path.is_file()
):
    raise SystemExit("T65 public candidate executed the G2 action stub")

parent_gates = gates(parent)
if parent_gates != ["g0-release-ledger", *g1, "g2-boot"]:
    raise SystemExit(f"T65 parent control did not reach G2 after the fixed G1 order: {parent_gates!r}")
stderr = (parent / "native" / "g2-boot.stderr").read_text(encoding="utf-8")
if "T65_PUBLIC_G2_BOOT_ACTION" not in stderr:
    raise SystemExit(f"T65 parent control did not fail at the G2 action stub: {stderr!r}")
if (parent / "final-result.json").exists():
    raise SystemExit("T65 parent control unexpectedly emitted a terminal result")
if any(gate.startswith(("g3-", "g4-")) for gate in parent_gates) or (parent / "chromium").exists():
    raise SystemExit("T65 parent control reached a later gate after G2")
PY
  if [ "${SELF_TEST_T65_PUBLIC_FLOW_ONLY:-0}" = "1" ]; then
    printf 'Browser Product Gate 2 T65 public-flow self-test OK\n'
    return
  fi

  git -C "$qemu_root" checkout -q "$h12"
  BUS_GATE2_QEMU_COMMIT=$h12
  BUS_GATE2_ACTIVE_SOURCE_OWNER=bus_engine_os
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  CASE_ID=composed
  ROLE=candidate-pass
  RESULT_DIR=$out
  PLAN_MODE=1
  unset BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256
  validate_role
  validate_identity_inputs
  validate_qemu_host_only_range >/dev/null

  release_ledger_json=$(cat "$BUS_GATE2_RELEASE_LEDGER")
  validate_release_ledger "$BUS_GATE2_RELEASE_LEDGER" "$TUPLE_FORMAT"
  for health_key in truthful_telemetry control_api_responsive supervisor_accepted; do
    python3 - "$BUS_GATE2_RELEASE_LEDGER" "$health_key" <<'PY'
import json, sys
path, key = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
del doc[key]
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f)
PY
    assert_fail "$health_key" validate_release_ledger "$BUS_GATE2_RELEASE_LEDGER" "$TUPLE_FORMAT"
    printf '%s\n' "$release_ledger_json" >"$BUS_GATE2_RELEASE_LEDGER"
    python3 - "$BUS_GATE2_RELEASE_LEDGER" "$health_key" <<'PY'
import json, sys
path, key = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc[key] = False
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f)
PY
    assert_fail "$health_key" validate_release_ledger "$BUS_GATE2_RELEASE_LEDGER" "$TUPLE_FORMAT"
    printf '%s\n' "$release_ledger_json" >"$BUS_GATE2_RELEASE_LEDGER"
  done
  validate_release_ledger "$BUS_GATE2_RELEASE_LEDGER" "$TUPLE_FORMAT"
  delta_json >"$SELF_TMP/source-delta-composed.json"
  python3 - "$SELF_TMP/source-delta-composed.json" "$h6" "$h7" "$h8" "$h9" "$h10" "$h1" <<'PY'
import json, sys
path, t64_parent, t64_candidate, t65_parent, t65_candidate, t154_candidate, t66_tip = sys.argv[1:8]
doc = json.load(open(path, encoding="utf-8"))
if doc.get("verified_owner") != "bus_engine_os":
    raise SystemExit("composed verified_owner must remain the active repository owner")
if doc.get("verified_parent") != "" or doc.get("verified_candidate") != "":
    raise SystemExit("composed generic parent/candidate fields must stay empty")
if doc.get("relationship_result") != "verified-composed-containment":
    raise SystemExit("wrong composed relationship_result")
want_fixed = {
    "t64": {"owner": "bus_engine_os", "parent": t64_parent, "candidate": t64_candidate},
    "t65": {"owner": "qemu", "parent": t65_parent, "candidate": t65_candidate},
    "t154": {"owner": "qemu", "parent": t65_parent, "candidate": t154_candidate},
    "t66": {"owner": "bus_engine_os", "tip": t66_tip},
}
if doc.get("verified_fixed_roles") != want_fixed:
    raise SystemExit("wrong composed fixed-role identities")
want_containment = {
    "bus_engine_os_t64": "true",
    "bus_engine_os_t66": "true",
    "qemu_t65": "true",
    "qemu_t154": "true",
}
if doc.get("composed_containment") != want_containment:
    raise SystemExit("wrong composed containment record")
PY
  local composed_digest=$BUS_GATE2_SCENARIO_DIGEST
  BUS_GATE2_BUSDK_COMMIT=1e060b120dd1f9396fdd6c1c1d833a8dacb26beb assert_fail "BUS_GATE2_BUSDK_COMMIT mismatch" validate_identity_inputs
  BUS_GATE2_BUSDK_COMMIT=$busdk_composed_commit
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h6 assert_fail "BUS_GATE2_BUS_ENGINE_OS_COMMIT mismatch" validate_identity_inputs
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h1
  BUS_GATE2_T50_PARENT_COMMIT=$h4
  BUS_GATE2_T50_CANDIDATE_COMMIT=$h5
  BUS_GATE2_G4_SERIAL_INPUT_FILE=$artifact_dir/serial.txt
  BUS_GATE2_G4_SERIAL_INPUT_SHA256=$(sha256_file "$artifact_dir/serial.txt")
  export BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256
  CASE_ID=T50
  ROLE=parent-fail
  git -C "$os_root" checkout -q "$h4"
  git -C "$busdk_root" checkout -q "$busdk_t50_parent_commit"
  BUS_GATE2_BUSDK_COMMIT=$busdk_t50_parent_commit
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h4
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h4
  EXPECTED_FAIL_GATE=g2-boot
  EXPECTED_FAIL_PREDICATE='bus-engine-os login:'
  validate_role
  validate_identity_inputs
  local t50_parent_digest=$BUS_GATE2_SCENARIO_DIGEST
  [ "$composed_digest" != "$t50_parent_digest" ] || die "cold composed scenario must differ from standalone T50"
  local bundle_size=$BUS_GATE2_BUNDLE_DIR_SIZE
  BUS_GATE2_BUNDLE_DIR_SIZE=$((bundle_size + 1)) assert_fail "BUS_GATE2_BUNDLE_DIR_SIZE mismatch" validate_identity_inputs
  BUS_GATE2_BUNDLE_DIR_SIZE=$bundle_size
  validate_identity_inputs
  [ "$t50_parent_digest" = "$BUS_GATE2_SCENARIO_DIGEST" ] || die "standalone T50 scenario digest changed with role"
  git -C "$os_root" checkout -q "$h5"
  git -C "$busdk_root" checkout -q "$busdk_t50_candidate_commit"
  BUS_GATE2_BUSDK_COMMIT=$busdk_t50_candidate_commit
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h5
  CASE_ID=T50
  ROLE=parent-fail
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h5
  EXPECTED_FAIL_GATE=g2-boot
  EXPECTED_FAIL_PREDICATE='bus-engine-os login:'
  assert_fail "T50 parent-fail must bind the fixed expected commit" validate_identity_inputs

  ROLE=candidate-pass
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  local candidate_plan="$SELF_TMP/t50-candidate-plan"
  RESULT_DIR=$candidate_plan
  PLAN_MODE=1
  run_harness >/dev/null
  python3 - "$candidate_plan" <<'PY'
import json
from pathlib import Path
import sys

candidate_root = Path(sys.argv[1])

def load(root, name):
    with (root / name).open(encoding="utf-8") as handle:
        return json.load(handle)

def canonical_argv(root, relative):
    lines = (root / relative).read_text(encoding="utf-8").splitlines()
    return [line.replace(str(root), "<RESULT_DIR>") for line in lines]

records = [line.split("\t") for line in (candidate_root / "status.tsv").read_text(encoding="utf-8").splitlines()]
if any(len(record) < 2 or record[1] != "PLAN" for record in records):
    raise SystemExit("standalone T50 plan did not remain plan-only")

scenario = load(candidate_root, "scenario.json")
if scenario.get("serial_after") != "QEMU_WASM_SNAPSHOT_READY" or not scenario.get("serial_text_sha256"):
    raise SystemExit("standalone T50 lost serial resume scenario fields")
if "console_readiness_marker" in scenario or "console_duplex_primary_serial" in scenario:
    raise SystemExit("standalone T50 retained cold-only scenario fields")
argv = canonical_argv(candidate_root, Path("chromium/g4-chromium.argv.txt"))
for required in (
    "QEMU_WASM_SNAPSHOT_RELEASED",
    "bus-engine-os-first-resume-identity: identity-evidence",
    "QEMU_WASM_SNAPSHOT_READY",
    "QEMU_WASM_RESUME_CONTINUE",
    "--serial-input-after-text",
    "--serial-input-text",
    "--pre-serial-input-wait-ms",
    "--service-request-operation",
    "initialize",
    "--service-request-timeout-ms",
    "10000",
    "--qemu-arg",
    "-device",
    "virtio-rng-device",
):
    if required not in argv:
        raise SystemExit(f"standalone T50 argv lost required term: {required}")
proof_argv = canonical_argv(candidate_root, Path("chromium/g4-generated-exec-proof.argv.txt"))
for required in ("--require-service-roundtrip", "initialize"):
    if required not in proof_argv:
        raise SystemExit(f"standalone T50 proof argv lost required term: {required}")
pins = load(candidate_root, "artifacts.json").get("pins", {})
if "t50_parent" not in pins or "t50_candidate" not in pins:
    raise SystemExit("standalone T50 artifacts lost required T50 pins")
delta = load(candidate_root, "source-deltas.json")
if "t50" not in delta.get("verified_fixed_roles", {}):
    raise SystemExit("standalone T50 source delta lost required T50 identity")
PY
  local t50_serial_file=$BUS_GATE2_G4_SERIAL_INPUT_FILE t50_serial_sha=$BUS_GATE2_G4_SERIAL_INPUT_SHA256
  unset BUS_GATE2_G4_SERIAL_INPUT_FILE
  assert_fail "missing required field: BUS_GATE2_G4_SERIAL_INPUT_FILE" validate_identity_inputs
  BUS_GATE2_G4_SERIAL_INPUT_FILE=$t50_serial_file
  BUS_GATE2_G4_SERIAL_INPUT_SHA256=short
  assert_fail "BUS_GATE2_G4_SERIAL_INPUT_SHA256 must be lowercase 64-hex" validate_identity_inputs
  BUS_GATE2_G4_SERIAL_INPUT_SHA256=$t50_serial_sha
  export BUS_GATE2_G4_SERIAL_INPUT_FILE BUS_GATE2_G4_SERIAL_INPUT_SHA256

  git -C "$os_root" checkout -q "$h1"
  git -C "$busdk_root" checkout -q "$busdk_composed_commit"
  BUS_GATE2_BUSDK_COMMIT=$busdk_composed_commit
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h1
  ROLE=candidate-pass
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  BUS_GATE2_T65_CANDIDATE_COMMIT=$h8 assert_fail "BUS_GATE2_T65_CANDIDATE_COMMIT must equal fixed T65 candidate" validate_identity_inputs
  BUS_GATE2_T65_CANDIDATE_COMMIT=$h9
  ROLE_T65_CANDIDATE=$h8 assert_fail "T65 parent and candidate must differ" validate_identity_inputs
  ROLE_T65_CANDIDATE=$h9
  ROLE_T65_PARENT=$h9 ROLE_T65_CANDIDATE=$h8 assert_fail "T65 parent is not an ancestor of candidate" validate_identity_inputs
  ROLE_T65_PARENT=$h8 ROLE_T65_CANDIDATE=$h9
  BUS_GATE2_T154_CANDIDATE_COMMIT=$h8 assert_fail "BUS_GATE2_T154_CANDIDATE_COMMIT must equal fixed T154 candidate" validate_identity_inputs
  BUS_GATE2_T154_CANDIDATE_COMMIT=$h10
  ROLE_T154_CANDIDATE=$h8 assert_fail "T154 parent and candidate must differ" validate_identity_inputs
  ROLE_T154_CANDIDATE=$h10
  ROLE_T154_PARENT=$h10 ROLE_T154_CANDIDATE=$h8 assert_fail "T154 parent is not an ancestor of candidate" validate_identity_inputs
  ROLE_T154_PARENT=$h8 ROLE_T154_CANDIDATE=$h10
  ROLE_T50_PARENT=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa assert_fail "T50 parent commit is not present in owning repository" validate_identity_inputs
  ROLE_T50_PARENT=$h4
  ROLE_T65_PARENT=$h5 assert_fail "T65 parent commit is not present in owning repository" validate_identity_inputs
  ROLE_T65_PARENT=$h8
  ROLE_T154_PARENT=$h5 assert_fail "T154 parent commit is not present in owning repository" validate_identity_inputs
  ROLE_T154_PARENT=$h8
  git -C "$os_root" checkout -q "$h4"
  self_write_file "$os_root/missing-t50.txt" "missing-t50"
  git -C "$os_root" add missing-t50.txt
  git -C "$os_root" commit -q -m "missing t50 side"
  local missing_t50
  missing_t50=$(git -C "$os_root" rev-parse HEAD)
  git -C "$os_root" checkout -q "$h6"
  self_write_file "$os_root/missing-t64.txt" "missing-t64"
  git -C "$os_root" add missing-t64.txt
  git -C "$os_root" commit -q -m "missing t64 side"
  local missing_t64
  missing_t64=$(git -C "$os_root" rev-parse HEAD)
  git -C "$os_root" checkout -q "$h7"
  self_write_file "$os_root/missing-t66.txt" "missing-t66"
  git -C "$os_root" add missing-t66.txt
  git -C "$os_root" commit -q -m "missing t66 side"
  local missing_t66
  missing_t66=$(git -C "$os_root" rev-parse HEAD)
  git -C "$os_root" checkout -q "$h1"
  git -C "$qemu_root" checkout -q "$h8"
  self_write_file "$qemu_root/missing-t65.txt" "missing-t65"
  git -C "$qemu_root" add missing-t65.txt
  git -C "$qemu_root" commit -q -m "missing t65 side"
  local missing_t65
  missing_t65=$(git -C "$qemu_root" rev-parse HEAD)
  git -C "$qemu_root" checkout -q "$h8"
  self_write_file "$qemu_root/missing-t154.txt" "missing-t154"
  git -C "$qemu_root" add missing-t154.txt
  git -C "$qemu_root" commit -q -m "missing t154 side"
  local missing_t154
  missing_t154=$(git -C "$qemu_root" rev-parse HEAD)
  git -C "$qemu_root" checkout -q "$h12"
  CASE_ID=composed
  BUS_GATE2_ACTIVE_SOURCE_OWNER=qemu
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h12
  BUS_GATE2_QEMU_COMMIT=$h12
  assert_fail "composed candidate-pass must bind fixed Bus Engine OS owner" validate_identity_inputs
  BUS_GATE2_ACTIVE_SOURCE_OWNER=bus_engine_os
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  BUS_GATE2_QEMU_COMMIT=$h12
  CASE_ID=composed
  ROLE_T50_CANDIDATE=$missing_t50
  unset BUS_GATE2_T50_PARENT_COMMIT BUS_GATE2_T50_CANDIDATE_COMMIT
  validate_identity_inputs
  ROLE_T50_CANDIDATE=$h5
  BUS_GATE2_T50_PARENT_COMMIT=$h4
  BUS_GATE2_T50_CANDIDATE_COMMIT=$h5
  ROLE_T64_CANDIDATE=$missing_t64
  BUS_GATE2_T64_CANDIDATE_COMMIT=$missing_t64
  assert_fail "composed T64 candidate is not contained" validate_identity_inputs
  ROLE_T64_CANDIDATE=$h7
  BUS_GATE2_T64_CANDIDATE_COMMIT=$h7
  ROLE_T66_TIP=$missing_t66
  BUS_GATE2_T66_TIP_COMMIT=$missing_t66
  assert_fail "composed T66 dependency is not contained" validate_identity_inputs
  ROLE_T66_TIP=$h1
  BUS_GATE2_T66_TIP_COMMIT=$h1
  ROLE_T65_CANDIDATE=$missing_t65
  BUS_GATE2_T65_CANDIDATE_COMMIT=$missing_t65
  assert_fail "composed T65 candidate is not contained" validate_identity_inputs
  ROLE_T65_CANDIDATE=$h9
  BUS_GATE2_T65_CANDIDATE_COMMIT=$h9
  ROLE_T154_CANDIDATE=$missing_t154
  BUS_GATE2_T154_CANDIDATE_COMMIT=$missing_t154
  assert_fail "composed T154 candidate is not contained" validate_identity_inputs
  ROLE_T154_CANDIDATE=$h10
  BUS_GATE2_T154_CANDIDATE_COMMIT=$h10
  CASE_ID=T64
  ROLE=parent-fail
  assert_fail "T64 parent-fail has no packet-owned package/import-wrapper predicate" validate_role
  CASE_ID=T50
  ROLE=parent-fail
  EXPECTED_FAIL_GATE=g1-beo-generated-rootfs-policy assert_fail "parent-fail gate is harness-owned" validate_role
  EXPECTED_FAIL_GATE=g2-boot
  EXPECTED_FAIL_PREDICATE=wrong assert_fail "parent-fail predicate is harness-owned" validate_role
  ROLE=candidate-pass
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  CASE_ID=composed
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  ROLE=candidate-pass
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=short assert_fail "lowercase 40-hex" validate_identity_inputs
  BUS_GATE2_BUS_ENGINE_OS_COMMIT=$h1
  BUS_GATE2_BROWSER_IMAGE_ID=busdk:latest assert_fail "sha256:<64 lowercase hex>" validate_identity_inputs
  BUS_GATE2_BROWSER_IMAGE_ID=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  BUS_GATE2_KERNEL_SIZE=999 assert_fail "BUS_GATE2_KERNEL_SIZE mismatch" validate_identity_inputs
  BUS_GATE2_KERNEL_SIZE=$(file_size "$BUS_GATE2_KERNEL")

  mkdir -p "$SELF_TMP/chromium"
  cat >"$SELF_TMP/chromium/result.json" <<'EOF'
{"success":true,"marker":"bus-engine-os login:","markerSeen":true,"elapsedMs":40075,"browserVersion":{"browser":"HeadlessChrome/150.0.0.0"},"pageErrors":[],"resourceErrors":[],"expectedTextSeen":[{"text":"QEMU_WASM_SERVICE_READY","seen":true},{"text":"bus-engine-os-browser-http-proof: http-ok","seen":true},{"text":"storage-marker","seen":true}],"serviceRoundtrip":{"source":"qemuWasmServiceBridge.request","operation":"initialize","requestId":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab","timeoutMs":10000,"readiness":{"readyBefore":true,"readyAfter":true,"readySourceBefore":"serial","readySourceAfter":"serial","moduleAttachedBefore":true,"moduleAttachedAfter":true,"interactiveOnlyBefore":true,"interactiveOnlyAfter":true,"healthRequestedBefore":false,"healthRequestedAfter":false},"transport":{"pendingBefore":0,"pendingAfter":0,"sentBefore":0,"sentAfter":1,"receivedBefore":0,"receivedAfter":1,"resolvedBefore":0,"resolvedAfter":1,"timedOutBefore":0,"timedOutAfter":0,"lastRequestId":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab","lastResponseId":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab"},"response":{"id":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab","operation":"initialize","status":"ok","adapter":"ready","app_server":"initialized"},"responseProjectionSafe":true,"classification":"success","timing":{"startedAtMs":40000,"completedAtMs":40075,"elapsedMs":75}}}
EOF
  cat >"$SELF_TMP/chromium/g4-generated-exec-proof.stdout" <<'EOF'
{"purpose":"qemu-browser-cdp-proof-gate","ok":true,"success":true,"generatedExec":{"ok":true,"source":"wasm64Runloop","generatedRunEntries":7},"serviceRoundtrip":{"ok":true,"operation":"initialize","requestId":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab","classification":"success","response":{"id":"gate2-initialize-01234567-89ab-4cde-8fab-0123456789ab","operation":"initialize","status":"ok","adapter":"ready","app_server":"initialized"},"elapsedMs":75}}
EOF
  CASE_ID=composed
  RESULT_DIR=$SELF_TMP/tuple-composed-out
  mkdir -p "$RESULT_DIR"
  write_tuple_from_result "$SELF_TMP/chromium"
  test -f "$RESULT_DIR/tuple.json"
  local composed_fixture=$SELF_TMP/chromium/result.json
  local composed_fixture_backup=$SELF_TMP/chromium/result.base.json
  cp "$composed_fixture" "$composed_fixture_backup"
  local roundtrip_mutation
  for roundtrip_mutation in missing fabricated health pending sent mismatch error adapter app-server timeout timing forbidden-body; do
    cp "$composed_fixture_backup" "$composed_fixture"
    python3 - "$composed_fixture" "$roundtrip_mutation" <<'PY'
import json, sys
p, mutation = sys.argv[1:3]
d = json.load(open(p, encoding="utf-8"))
r = d.get("serviceRoundtrip")
if mutation == "missing":
    del d["serviceRoundtrip"]
elif mutation == "fabricated":
    d["frontend_roundtrip"] = {"c_accepted": True, "guest_originated_response": True}
elif mutation == "health":
    r["readiness"]["healthRequestedAfter"] = True
elif mutation == "pending":
    r["transport"]["pendingBefore"] = 1
elif mutation == "sent":
    r["transport"]["sentAfter"] = 2
elif mutation == "mismatch":
    r["transport"]["lastResponseId"] = "wrong"
elif mutation == "error":
    r["response"]["status"] = "error"
elif mutation == "adapter":
    r["response"]["adapter"] = "starting"
elif mutation == "app-server":
    r["response"]["app_server"] = "missing"
elif mutation == "timeout":
    r["classification"] = "timeout"
elif mutation == "timing":
    r["timing"]["elapsedMs"] = 10001
elif mutation == "forbidden-body":
    r["response"]["body"] = "must-not-be-accepted"
json.dump(d, open(p, "w", encoding="utf-8"))
PY
    assert_fail "runtime roundtrip invariant failed:" write_tuple_from_result "$SELF_TMP/chromium"
  done
  cp "$composed_fixture_backup" "$composed_fixture"
  cp "$SELF_TMP/chromium/g4-generated-exec-proof.stdout" "$SELF_TMP/chromium/proof.base.json"
  python3 - "$SELF_TMP/chromium/g4-generated-exec-proof.stdout" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["serviceRoundtrip"]["ok"] = False
json.dump(d, open(p, "w", encoding="utf-8"))
PY
  assert_fail "runtime roundtrip invariant failed: proof gate" write_tuple_from_result "$SELF_TMP/chromium"
  cp "$SELF_TMP/chromium/proof.base.json" "$SELF_TMP/chromium/g4-generated-exec-proof.stdout"
  write_tuple_from_result "$SELF_TMP/chromium"
  test -f "$RESULT_DIR/tuple.json"

  RESULT_DIR=$SELF_TMP/cleanup-fail
  mkdir -p "$RESULT_DIR/chromium"
  printf 'cleanup_policy=exact-container-name-and-labels\n' >"$RESULT_DIR/cleanup.log"
  PLAN_MODE=0
  G4_STARTED=0
  docker() { printf 'docker should not run before G4\n' >&2; return 99; }
  cleanup_g4
  G4_STARTED=1
  docker() { return 42; }
  if cleanup_g4 >/dev/null 2>&1; then die "cleanup inspect failure should fail closed"; fi
  grep -F 'cleanup_error=inspect-before-failed' "$RESULT_DIR/cleanup.log" >/dev/null
  RESULT_DIR=$SELF_TMP/cleanup-ok
  mkdir -p "$RESULT_DIR/chromium"
  printf 'cleanup_policy=exact-container-name-and-labels\n' >"$RESULT_DIR/cleanup.log"
  docker() { return 0; }
  cleanup_g4
  grep -F 'container_absent=true' "$RESULT_DIR/cleanup.log" >/dev/null
  G4_STARTED=0

  CASE_ID=composed
  ROLE=candidate-pass
  EXPECTED_FAIL_GATE=
  EXPECTED_FAIL_PREDICATE=
  RESULT_DIR=$SELF_TMP/plan
  PLAN_MODE=1
  BUS_GATE2_ACTIVE_SOURCE_OWNER=bus_engine_os
  BUS_GATE2_ACTIVE_SOURCE_COMMIT=$h1
  run_harness >/dev/null
  grep -F 'PLAN' "$SELF_TMP/plan/status.tsv" >/dev/null
  python3 - "$candidate_plan/status.tsv" "$SELF_TMP/plan/status.tsv" <<'PY'
import sys

def load_gates(path, require_plan=False):
    with open(path, encoding="utf-8") as f:
        records = [line.rstrip("\n").split("\t") for line in f]
    if require_plan and (not records or any(len(record) < 2 or record[1] != "PLAN" for record in records)):
        raise SystemExit("composed plan did not remain plan-only")
    return [record[0] for record in records]

t50_gates = load_gates(sys.argv[1])
composed_gates = load_gates(sys.argv[2], require_plan=True)
lock_gate = composed_gates.index("g3-heavy-lock-non-overlap")
chromium_gate = composed_gates.index("g4-chromium")
if lock_gate + 1 != chromium_gate:
    raise SystemExit("heavy lock readback gate must immediately precede G4")
for gate in (
    "g1-qemu-presence-serial-input-after-text-gate",
    "g1-qemu-presence-serial-input-after-text-test",
    "g1-qemu-presence-serial-input-text-gate",
    "g1-qemu-presence-serial-input-text-test",
    "g1-qemu-presence-pre-serial-input-wait-ms-gate",
    "g1-qemu-presence-pre-serial-input-wait-ms-test",
):
    if gate not in t50_gates:
        raise SystemExit(f"standalone T50 lost serial-input support gate: {gate}")
    if gate in composed_gates:
        raise SystemExit(f"cold composed retained serial-input support gate: {gate}")
PY
  grep -F 'g1-qemu-wasm-browser-cdp-proof-gate-test' "$SELF_TMP/plan/status.tsv" >/dev/null
  python3 - "$SELF_TMP/plan/chromium/g4-generated-exec-proof.argv.txt" "$SELF_TMP/plan/chromium/result.json" "$SELF_TMP/plan/chromium/g4-chromium.argv.txt" "$SELF_TMP/plan/scenario.json" "$SELF_TMP/plan/artifacts.json" "$SELF_TMP/plan/source-deltas.json" "$SELF_TMP/tuple-composed-out/tuple.json" "$h11" "$h12" <<'PY'
import json
import sys
proof_path, result_path, chromium_path, scenario_path, artifacts_path, delta_path, tuple_path, compiled_source, host_source = sys.argv[1:10]
with open(proof_path, encoding="utf-8") as f:
    proof = f.read().splitlines()
expected = [
    "node",
    "scripts/ci/wasm-browser-cdp-proof-gate.mjs",
    "--result",
    result_path,
    "--require-generated-exec",
    "--require-guest-manifest",
    "--require-service-roundtrip",
    "initialize",
    "--require-success",
    "--max-elapsed-ms",
    "1200000",
    "--json",
]
if proof != expected:
    raise SystemExit(f"wrong generated proof argv: {proof!r}")
with open(chromium_path, encoding="utf-8") as f:
    chromium = f.read().splitlines()
disabled = "--no-live-" + "generated-exec"
if disabled in chromium:
    raise SystemExit("generated execution is disabled")
for forbidden in (
    "QEMU_WASM_SNAPSHOT_READY",
    "QEMU_WASM_RESUME_CONTINUE",
    "QEMU_WASM_SNAPSHOT_RELEASED",
    "resume",
    "snapshot",
    "--serial-input-after-text",
    "--serial-input-text",
    "--pre-serial-input-wait-ms",
):
    if any(forbidden.lower() in arg.lower() for arg in chromium):
        raise SystemExit(f"cold composed argv retained forbidden term: {forbidden}")
for required in (
    "--marker",
    "bus-engine-os login:",
    "QEMU_WASM_SERVICE_READY",
    "bus-engine-os-browser-http-proof: http-ok",
    "storage-marker",
    "--service-request-operation",
    "initialize",
    "--service-request-timeout-ms",
    "10000",
    "--qemu-arg",
    "-device",
    "virtio-rng-device",
  ):
    if required not in chromium:
        raise SystemExit(f"cold composed argv lost required term: {required}")
with open(scenario_path, encoding="utf-8") as f:
    scenario = json.load(f)
if scenario.get("console_readiness_marker") != "bus-engine-os login:" or scenario.get("console_duplex_primary_serial") is not True:
    raise SystemExit("cold console contract missing from scenario")
if scenario.get("service_request") != {"operation": "initialize", "timeout_ms": 10000}:
    raise SystemExit("cold service request contract missing from scenario")
if scenario.get("kernel_enablement") != "bus.engine.codex_app_server=1":
    raise SystemExit("Codex kernel enablement missing from scenario")
if "serial_after" in scenario or "serial_text_sha256" in scenario:
    raise SystemExit("cold scenario retained serial resume input")
with open(artifacts_path, encoding="utf-8") as f:
    artifacts = json.load(f)
if any(key.startswith("t50_") for key in artifacts.get("pins", {})):
    raise SystemExit("composed artifacts retain T50 inputs")
split = artifacts.get("qemu_source_split", {})
if split.get("compiled_artifact_source") != compiled_source:
    raise SystemExit("self-test compiled QEMU source mismatch")
if split.get("host_gate_candidate") != host_source:
    raise SystemExit("self-test host runtime source mismatch")
if split.get("host_gate_candidate") == split.get("compiled_artifact_source"):
    raise SystemExit("self-test QEMU source split collapsed distinct identities")
if split.get("compiled_inputs_changed") is not False:
    raise SystemExit("compiled QEMU inputs must remain unchanged")
with open(delta_path, encoding="utf-8") as f:
    delta = json.load(f)
if "t50" in delta.get("verified_fixed_roles", {}) or "bus_engine_os_t50" in delta.get("composed_containment", {}):
    raise SystemExit("composed result retains T50 containment")
for label, path in {
    "scenario": scenario_path,
    "artifacts": artifacts_path,
    "source delta": delta_path,
    "G4 argv": chromium_path,
    "result predicates": tuple_path,
}.items():
    with open(path, encoding="utf-8") as f:
        text = f.read().lower()
    for forbidden in ("t50", "resume", "snapshot", "serial-input"):
        if forbidden in text:
            raise SystemExit(f"composed {label} retained forbidden term: {forbidden}")
PY
  if find "$SELF_TMP/plan" -name 'g4-chromium.stdout' -size +0c | grep -q .; then die "plan path unexpectedly executed heavy command"; fi
  mkdir -p "$SELF_TMP/nonempty"; printf keep >"$SELF_TMP/nonempty/evidence"
  assert_fail "refusing existing non-empty result directory" ensure_safe_result_dir "$SELF_TMP/nonempty"
  grep -F keep "$SELF_TMP/nonempty/evidence" >/dev/null
  printf 'Browser Product Gate 2 harness self-test OK\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --self-test) shift; [ "$#" -eq 0 ] || die "--self-test does not accept extra arguments"; self_test; exit 0 ;;
    --self-test-t65-public-flow) shift; [ "$#" -eq 0 ] || die "--self-test-t65-public-flow does not accept extra arguments"; SELF_TEST_T65_PUBLIC_FLOW_ONLY=1 self_test; exit 0 ;;
    --plan) PLAN_MODE=1; shift ;;
    --case) [ "$#" -ge 2 ] || die "missing value for --case"; CASE_ID=$2; shift 2 ;;
    --role) [ "$#" -ge 2 ] || die "missing value for --role"; ROLE=$2; shift 2 ;;
    --result-dir) [ "$#" -ge 2 ] || die "missing value for --result-dir"; RESULT_DIR=$2; shift 2 ;;
    --expected-fail-gate) [ "$#" -ge 2 ] || die "missing value for --expected-fail-gate"; EXPECTED_FAIL_GATE=$2; shift 2 ;;
    --expected-fail-predicate) [ "$#" -ge 2 ] || die "missing value for --expected-fail-predicate"; EXPECTED_FAIL_PREDICATE=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

run_harness
