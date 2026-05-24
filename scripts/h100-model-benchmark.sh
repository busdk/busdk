#!/usr/bin/env sh
set -eu

models="gemma4:31b,gpt-oss:120b"
endpoint="http://127.0.0.1:11434/api/generate"
prompt="Reply with exactly: Bus benchmark ok"
repeats=1
output="-"
timeout=180

usage() {
	cat <<USAGE
usage: h100-model-benchmark.sh [options]

Compare H100-local Ollama models and emit TSV rows:
model	repeat	status	elapsed_ms	response_bytes	error

Options:
  --models LIST       comma-separated models (default: $models)
  --endpoint URL      Ollama /api/generate endpoint (default: $endpoint)
  --prompt TEXT       prompt for each model run
  --repeats N         repetitions per model (default: $repeats)
  --output FILE       TSV output path, or - for stdout (default: -)
  --timeout SECONDS   curl max-time per request (default: $timeout)
  -h, --help          show this help
USAGE
}

die() {
	printf 'h100-model-benchmark: %s\n' "$*" >&2
	exit 2
}

need_arg() {
	if [ "$#" -lt 2 ]; then
		die "missing value for $1"
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--models) need_arg "$@"; models=$2; shift 2 ;;
		--endpoint) need_arg "$@"; endpoint=$2; shift 2 ;;
		--prompt) need_arg "$@"; prompt=$2; shift 2 ;;
		--repeats) need_arg "$@"; repeats=$2; shift 2 ;;
		--output) need_arg "$@"; output=$2; shift 2 ;;
		--timeout) need_arg "$@"; timeout=$2; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) die "unknown option: $1" ;;
	esac
done

case "$repeats" in
	''|*[!0-9]*) die "--repeats must be a positive integer" ;;
	0) die "--repeats must be a positive integer" ;;
esac
case "$timeout" in
	''|*[!0-9]*) die "--timeout must be a positive integer" ;;
	0) die "--timeout must be a positive integer" ;;
esac
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v sed >/dev/null 2>&1 || die "sed is required"
command -v wc >/dev/null 2>&1 || die "wc is required"

json_escape() {
	printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

now_ms() {
	value=$(date +%s%3N 2>/dev/null || true)
	case "$value" in
		''|*N*) value="$(date +%s)000" ;;
	esac
	printf '%s' "$value"
}

write_row() {
	if [ "$output" = "-" ]; then
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"
	else
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >>"$output"
	fi
}

if [ "$output" != "-" ]; then
	: >"$output"
fi

old_ifs=$IFS
IFS=,
set -- $models
IFS=$old_ifs

for model do
	model=$(printf '%s' "$model" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
	[ -n "$model" ] || continue
	i=1
	while [ "$i" -le "$repeats" ]; do
		response_file=$(mktemp "${TMPDIR:-/tmp}/h100-model-benchmark.XXXXXX")
		trap 'rm -f "$response_file"' EXIT HUP INT TERM
		escaped_model=$(json_escape "$model")
		escaped_prompt=$(json_escape "$prompt")
		payload="{\"model\":\"$escaped_model\",\"prompt\":\"$escaped_prompt\",\"stream\":false}"
		start=$(now_ms)
		status=ok
		error=
		if ! curl -fsS --max-time "$timeout" \
			-H 'Content-Type: application/json' \
			--data-binary "$payload" \
			-o "$response_file" \
			"$endpoint" 2>"$response_file.err"; then
			status=fail
			error=$(sed -n '1p' "$response_file.err" | tr '\t\n' '  ')
		elif grep -q '"error"' "$response_file"; then
			status=fail
			error=$(sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$response_file" | sed -n '1p' | tr '\t\n' '  ')
		fi
		end=$(now_ms)
		elapsed=$((end - start))
		bytes=$(wc -c <"$response_file" | sed 's/[[:space:]]//g')
		write_row "$model" "$i" "$status" "$elapsed" "$bytes" "$error"
		rm -f "$response_file" "$response_file.err"
		trap - EXIT HUP INT TERM
		i=$((i + 1))
	done
done
