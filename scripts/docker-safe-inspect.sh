#!/bin/sh
set -eu

usage() {
  printf 'usage: %s [container|image] <name-or-id> [<name-or-id>...]\n' "$0" >&2
  printf 'Print redacted Docker inspect metadata for containers or images.\n' >&2
}

kind=container
case "${1:-}" in
  container|image)
    kind=$1
    shift
    ;;
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

for target in "$@"; do
  case "$target" in
    ''|-*)
      printf 'invalid Docker inspect target: %s\n' "$target" >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required for redacted Docker inspection\n' >&2
  exit 2
fi

inspect_json=$(docker inspect --type "$kind" "$@")

printf '%s\n' "$inspect_json" | jq --arg kind "$kind" '
  def secret_key:
    test("(?i)(secret|token|password|passwd|pwd|credential|private[_-]?key|api[_-]?key|jwt|auth)");

  def redact_env:
    split("=") as $parts
    | ($parts[0] // "") as $name
    | ($parts[1:] | join("=")) as $value
    | if $name | secret_key then
        $name + "=<redacted:" + ($value | length | tostring) + " chars>"
      else
        .
      end;

  def redact_labels:
    (. // {})
    | with_entries(
        if .key | secret_key then
          .value = "<redacted>"
        else
          .
        end
      );

  if $kind == "container" then
    [
      .[]
      | {
          kind: "container",
          id: (.Id[0:12]),
          name: (.Name | ltrimstr("/")),
          image: .Config.Image,
          image_id: (.Image[0:12]),
          state: .State.Status,
          running: .State.Running,
          exit_code: .State.ExitCode,
          started_at: .State.StartedAt,
          finished_at: .State.FinishedAt,
          restart_count: .RestartCount,
          networks: ((.NetworkSettings.Networks // {}) | keys),
          mounts: [
            .Mounts[]?
            | {
                type: .Type,
                source: .Source,
                destination: .Destination,
                mode: .Mode,
                rw: .RW
              }
          ],
          env: [.Config.Env[]? | redact_env],
          labels: (.Config.Labels | redact_labels)
        }
    ]
  else
    [
      .[]
      | {
          kind: "image",
          id: (.Id[7:19] // .Id[0:12]),
          repo_tags: (.RepoTags // []),
          repo_digests: (.RepoDigests // []),
          created: .Created,
          size: .Size,
          architecture: .Architecture,
          os: .Os,
          user: .Config.User,
          working_dir: .Config.WorkingDir,
          env: [.Config.Env[]? | redact_env],
          labels: (.Config.Labels | redact_labels)
        }
    ]
  end
'
