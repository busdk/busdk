#!/bin/sh

# Shared worker-template resolver for shell launchers.
#
# Normal worker launch paths should select an environment-local template and
# let that template define exact provider model names. These helpers read the
# template catalog through bus-worker so scripts do not hard-code model IDs.

BUS_WORKER_TEMPLATE_ID=
BUS_WORKER_TEMPLATE_PROFILE=
BUS_WORKER_TEMPLATE_MODEL=
BUS_WORKER_TEMPLATE_REASONING_EFFORT=
BUS_WORKER_TEMPLATE_REASONING_SUMMARY=
BUS_WORKER_TEMPLATE_MODEL_VERBOSITY=
BUS_WORKER_TEMPLATE_RUNNER_KIND=
BUS_WORKER_TEMPLATE_RUNNER_PROVIDER=
BUS_WORKER_TEMPLATE_SANDBOX=

worker_template_value() {
	wtv_output=$1
	wtv_key=$2
	printf '%s\n' "$wtv_output" | awk -F '	' -v key="$wtv_key" '
		$1 == key {
			print $2
			found = 1
			exit
		}
		END {
			if (!found) {
				exit 1
			}
		}
	'
}

worker_template_empty_dash() {
	case "$1" in
		-) printf '' ;;
		*) printf '%s' "$1" ;;
	esac
}

resolve_worker_template() {
	rwt_root=$1
	rwt_template=$2
	if [ -z "$rwt_template" ]; then
		return 0
	fi
	rwt_bin=${BUS_WORKER_TEMPLATE_CLI:-$rwt_root/bus-worker/bin/bus-worker}
	if [ ! -x "$rwt_bin" ]; then
		printf 'worker template resolver not executable: %s\n' "$rwt_bin" >&2
		return 1
	fi
	rwt_output=$("$rwt_bin" -C "$rwt_root" template show "$rwt_template")
	BUS_WORKER_TEMPLATE_ID=$(worker_template_value "$rwt_output" id)
	BUS_WORKER_TEMPLATE_PROFILE=$(worker_template_value "$rwt_output" default_profile)
	BUS_WORKER_TEMPLATE_MODEL=$(worker_template_value "$rwt_output" default_model)
	BUS_WORKER_TEMPLATE_REASONING_EFFORT=$(worker_template_empty_dash "$(worker_template_value "$rwt_output" reasoning_effort)")
	BUS_WORKER_TEMPLATE_REASONING_SUMMARY=$(worker_template_empty_dash "$(worker_template_value "$rwt_output" reasoning_summary)")
	BUS_WORKER_TEMPLATE_MODEL_VERBOSITY=$(worker_template_empty_dash "$(worker_template_value "$rwt_output" model_verbosity)")
	BUS_WORKER_TEMPLATE_RUNNER_KIND=$(worker_template_value "$rwt_output" runner_kind)
	BUS_WORKER_TEMPLATE_RUNNER_PROVIDER=$(worker_template_value "$rwt_output" runner_provider)
	BUS_WORKER_TEMPLATE_SANDBOX=$(worker_template_value "$rwt_output" sandbox)
}
