#!/bin/sh
set -eu

stack_dir=$(pwd)
state_dir=${BUS_REPOS_SSH_STATE_DIR:-.bus/services/repos-ssh}
config=${BUS_REPOS_SSH_CONFIG:-$state_dir/sshd_config}
sshd_command=${BUS_REPOS_SSHD:-sshd}

case "$state_dir" in
/*) ;;
*) state_dir=$stack_dir/$state_dir ;;
esac

case "$config" in
/*) ;;
*) config=$stack_dir/$config ;;
esac

/bin/sh "$(dirname "$0")/bus-repos-ssh-init.sh" >/dev/null

case "$sshd_command" in
*/*) ;;
*)
	if sshd_path=$(command -v "$sshd_command" 2>/dev/null); then
		sshd_command=$sshd_path
	fi
	;;
esac

"$sshd_command" -D -e -f "$config"
