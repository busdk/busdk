#!/usr/bin/env bash
set -euo pipefail

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir="$root_dir/tmp/codex-image-refresh-smoke.$$"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  printf 'SKIP Codex image refresh smoke: docker not installed\n'
  exit 0
fi

base_image="busdk-codex-refresh-smoke-base:$$"
image="busdk-codex-refresh-smoke:$$"
workspace="$tmp_dir/workspace"
mkdir -p "$workspace/scripts"
cp scripts/busdk-refresh-tools.sh "$workspace/scripts/busdk-refresh-tools.sh"
chmod +x "$workspace/scripts/busdk-refresh-tools.sh"

for module in bus bus-dev bus-gx bus-lint bus-notes; do
  mkdir -p "$workspace/$module/cmd/$module"
  cat >"$workspace/$module/go.mod" <<EOF_MOD
module example.test/$module

go 1.24
EOF_MOD
done

cat >"$workspace/bus/cmd/bus/main.go" <<'EOF_GO'
package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	if len(os.Args) > 1 {
		var command string
		var args []string
		switch os.Args[1] {
		case "dev":
			command = "bus-dev"
			args = os.Args[2:]
		case "gx":
			command = "bus-gx"
			args = os.Args[2:]
		case "lint":
			command = "bus-lint"
			args = os.Args[2:]
		case "notes":
			command = "bus-notes"
			args = os.Args[2:]
		}
		if command != "" {
			cmd := exec.Command(command, args...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				os.Exit(1)
			}
			return
		}
	}
	fmt.Println("bus|help")
}
EOF_GO

for module in bus-dev bus-gx bus-lint bus-notes; do
  cat >"$workspace/$module/cmd/$module/main.go" <<'EOF_GO'
package main

import (
	"fmt"
	"os"
	"strings"
)

func main() {
	fmt.Printf("%s|%s\n", os.Args[0], strings.Join(os.Args[1:], " "))
}
EOF_GO
done

docker build -q -t "$base_image" deploy/local-ai-platform/codex >/dev/null
cat >"$tmp_dir/Dockerfile" <<EOF_DOCKER
FROM $base_image
COPY workspace /workspace
EOF_DOCKER
docker build -q -t "$image" "$tmp_dir" >/dev/null
trap 'docker rmi "$image" "$base_image" >/dev/null 2>&1 || true; rm -rf "$tmp_dir"' EXIT

docker run --rm "$image" sh -ec '
  test "$(command -v bus)" = /usr/local/bin/bus
  test "$(command -v bus-dev)" = /usr/local/bin/bus-dev
  test "$(command -v bus-gx)" = /usr/local/bin/bus-gx
  test "$(command -v bus-lint)" = /usr/local/bin/bus-lint
  test "$(command -v bus-notes)" = /usr/local/bin/bus-notes
  bus --help | grep -q "bus|help"
  bus dev work monitor --help | grep -q "bus-dev|work monitor --help"
  bus gx help | grep -q "bus-gx|help"
  bus lint --help | grep -q "bus-lint|--help"
  bus notes --help | grep -q "bus-notes|--help"
'

printf 'Codex image refresh smoke OK\n'
