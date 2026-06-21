#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gx-ui-adopter-audit.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bus-ui" "$TMP_DIR/bus-ledger/internal/ui/wasm" "$TMP_DIR/bus-chat/internal/serve" "$TMP_DIR/bus-not-ui"

cat >"$TMP_DIR/bus-ui/go.mod" <<'EOF'
module github.com/busdk/bus-ui

go 1.22
EOF

cat >"$TMP_DIR/bus-ledger/go.mod" <<'EOF'
module github.com/busdk/bus-ledger

go 1.22

require github.com/busdk/bus-ui v0.0.0
EOF

cat >"$TMP_DIR/bus-ledger/internal/ui/wasm/app.go" <<'EOF'
package wasm

import ui "github.com/busdk/bus-ui/pkg/ui"

func render() { _ = ui.Button }
EOF

cat >"$TMP_DIR/bus-ledger/internal/ui/wasm/local_view.go" <<'EOF'
package wasm

func renderLocalCard() string { return "<section class=\"local-card\">Draft</section>" }
EOF

cat >"$TMP_DIR/bus-ledger/internal/ui/wasm/logging.go" <<'EOF'
package wasm

func logDebug(message string) { _ = message }
EOF

cat >"$TMP_DIR/bus-chat/go.mod" <<'EOF'
module github.com/busdk/bus-chat

go 1.22

require github.com/busdk/bus-gx v0.0.0
EOF

cat >"$TMP_DIR/bus-chat/internal/serve/legacy.go" <<'EOF'
package serve

import "github.com/busdk/bus-ui/pkg/uikit"

func render() { _ = uikit.ButtonChecked }
EOF

cat >"$TMP_DIR/bus-not-ui/go.mod" <<'EOF'
module github.com/busdk/bus-not-ui

go 1.22
EOF

python3 "$ROOT_DIR/scripts/gx-ui-adopter-audit.py" --root "$TMP_DIR" --format json >"$TMP_DIR/audit.json"

python3 - "$TMP_DIR/audit.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

assert data["schema_version"] == "busdk.gx_ui_adopter_audit/v1", data
assert data["module_count"] == 3, data
assert data["forbidden_uikit_file_count"] == 1, data

modules = {item["module"]: item for item in data["modules"]}
assert "bus-ui" in modules, modules
assert modules["bus-ledger"]["ui_surface_file_count"] == 3, modules["bus-ledger"]
assert modules["bus-ledger"]["ui_import_file_count"] == 1, modules["bus-ledger"]
assert modules["bus-ledger"]["local_ui_candidate_file_count"] == 1, modules["bus-ledger"]
assert modules["bus-ledger"]["local_ui_infrastructure_file_count"] == 1, modules["bus-ledger"]
assert modules["bus-chat"]["forbidden_uikit_file_count"] == 1, modules["bus-chat"]
assert modules["bus-chat"]["local_ui_candidate_file_count"] == 0, modules["bus-chat"]
assert "bus-not-ui" not in modules, modules
PY

if python3 "$ROOT_DIR/scripts/gx-ui-adopter-audit.py" --root "$TMP_DIR" --fail-on-forbidden-uikit >/dev/null 2>&1; then
  echo "expected forbidden uikit audit to fail" >&2
  exit 1
fi

rm "$TMP_DIR/bus-chat/internal/serve/legacy.go"
cat >"$TMP_DIR/bus-chat/internal/serve/legacy.go" <<'EOF'
package serve

import gx "github.com/busdk/bus-gx/pkg/gx"

func render() { _ = gx.Text }
EOF

python3 "$ROOT_DIR/scripts/gx-ui-adopter-audit.py" --root "$TMP_DIR" --fail-on-forbidden-uikit >/dev/null
