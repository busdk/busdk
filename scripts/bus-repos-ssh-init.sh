#!/bin/sh
set -eu

stack_dir=$(pwd)
state_dir=${BUS_REPOS_SSH_STATE_DIR:-.bus/services/repos-ssh}
port=${BUS_REPOS_SSH_PORT:-2222}
listen=${BUS_REPOS_SSH_LISTEN:-127.0.0.1}
events_url=${BUS_REPOS_SSH_EVENTS_URL:-http://127.0.0.1:8081/local/v1}
token_file=${BUS_REPOS_SSH_TOKEN_FILE:-.bus/tokens/local-events.jwt}
environment_id=${BUS_REPOS_SSH_ENVIRONMENT_ID:-local-dev}
actor=${BUS_REPOS_SSH_ACTOR:-local-worker}
key_id=${BUS_REPOS_SSH_KEY_ID:-local-worker}
bus_command=${BUS_REPOS_SSH_BUS:-}
tool_path=${BUS_REPOS_SSH_TOOL_PATH:-${PATH:-}}

case "$state_dir" in
/*) ;;
*) state_dir=$stack_dir/$state_dir ;;
esac

case "$token_file" in
/*) ;;
*) token_file=$stack_dir/$token_file ;;
esac

if [ -z "$bus_command" ]; then
	if bus_path=$(command -v bus 2>/dev/null); then
		bus_command=$bus_path
	else
		bus_command=bus
	fi
fi

mkdir -p "$state_dir/keys" "$state_dir/run" "$state_dir/logs"
chmod 700 "$state_dir" "$state_dir/keys"

host_key="$state_dir/keys/host_ed25519"
client_key="$state_dir/keys/client_ed25519"
config="$state_dir/sshd_config"
authorized_keys="$state_dir/authorized_keys"
known_hosts="$state_dir/known_hosts"
command_script="$state_dir/ssh-command.sh"

if [ ! -f "$host_key" ]; then
	ssh-keygen -q -t ed25519 -N '' -f "$host_key"
fi

if [ ! -f "$client_key" ]; then
	ssh-keygen -q -t ed25519 -N '' -f "$client_key"
fi

cat >"$command_script" <<EOF
#!/bin/sh
PATH="$tool_path"
export PATH
exec "$bus_command" repos ssh-serve \\
  --actor "$actor" \\
  --key-id "$key_id" \\
  --events-url "$events_url" \\
  --token-file "$token_file" \\
  --environment-id "$environment_id"
EOF
chmod 700 "$command_script"

client_pub=$(cat "$client_key.pub")
printf 'command="%s",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding %s\n' "$command_script" "$client_pub" >"$authorized_keys"
chmod 600 "$authorized_keys"

host_pub=$(cat "$host_key.pub")
if [ "$port" = "22" ]; then
	printf '%s %s\n' "$listen" "$host_pub" >"$known_hosts"
else
	printf '[%s]:%s %s\n' "$listen" "$port" "$host_pub" >"$known_hosts"
fi
chmod 600 "$known_hosts"

user_name=${USER:-${LOGNAME:-}}
allow_users=
if [ -n "$user_name" ]; then
	allow_users="AllowUsers $user_name"
fi

cat >"$config" <<EOF
Port $port
ListenAddress $listen
HostKey $host_key
AuthorizedKeysFile $authorized_keys
PidFile $state_dir/run/sshd.pid
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitRootLogin no
UsePAM no
StrictModes no
PermitTTY no
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
PermitTunnel no
PermitUserEnvironment no
LogLevel VERBOSE
$allow_users
EOF
chmod 600 "$config"

printf '%s\n' "$config"
