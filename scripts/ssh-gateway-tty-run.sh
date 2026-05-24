#!/bin/sh
set -eu

# Runs a shell script through SSH gateways that require an interactive TTY and
# do not accept `ssh host command`. The script waits for the remote prompt
# before sending the payload, which covers managed GPU shell gateways that ignore
# pre-opened stdin.

if [ "$#" -ne 1 ]; then
	printf 'usage: %s user@host < script.sh\n' "$0" >&2
	exit 2
fi

if ! command -v expect >/dev/null 2>&1; then
	printf 'expect is required for interactive gateway TTY command execution\n' >&2
	exit 2
fi

target=$1
timeout_seconds=${BUS_SSH_GATEWAY_TTY_TIMEOUT_SECONDS:-3600}
payload=$(mktemp "${TMPDIR:-/tmp}/bus-ssh-gateway-tty-run.XXXXXX")
trap 'rm -f "$payload"' EXIT INT TERM

cat > "$payload"

expect -f - "$target" "$payload" "$timeout_seconds" <<'EXPECT'
set target [lindex $argv 0]
set payload [lindex $argv 1]
set timeout [lindex $argv 2]
set prompt_re {[$#%] $}
set marker "__BUS_GATEWAY_TTY_RUN_EXIT__"
set remote_tmp "/tmp/bus-gateway-tty-run-[pid].sh"
set delim "__BUS_GATEWAY_TTY_RUN_[pid]_[clock seconds]__"
set exit_code 124

proc wait_prompt {prompt_re} {
	expect {
		-re $prompt_re {
			return 0
		}
		timeout {
			puts stderr "timed out waiting for remote shell prompt"
			return 1
		}
		eof {
			puts stderr "remote shell closed before prompt"
			return 1
		}
	}
}

spawn ssh -A -tt $target
if {[wait_prompt $prompt_re] != 0} {
	exit 124
}

send -- "stty -echo || true\r"
expect {
	-re $prompt_re {}
	timeout {}
	eof {
		puts stderr "remote shell closed after stty"
		exit 124
	}
}

send -- "cat > $remote_tmp <<'$delim'\r"
set fh [open $payload r]
while {[gets $fh line] >= 0} {
	send -- $line
	send -- "\r"
}
close $fh
send -- "$delim\r"
send -- "sh $remote_tmp; rc=\$?; rm -f $remote_tmp; printf '\\n$marker:%s\\n' \"\$rc\"; exit \"\$rc\"\r"

expect {
	-re "$marker:([0-9]+)" {
		set exit_code $expect_out(1,string)
		exp_continue
	}
	eof {}
	timeout {
		puts stderr "timed out waiting for remote command completion"
		exit 124
	}
}

exit $exit_code
EXPECT
