#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PANE_PID="$1"

exit_safely_if_empty_ppid() {
	if [ -z "$PANE_PID" ]; then
		exit 0
	fi
}

full_command() {
	ps -ao "ppid,args" |
		sed "s/^ *//" |
		# Anchored on the space: without it a pane_pid of 2255 also matches ppid
		# 22551, and the unrelated descendants come out as extra lines in a file
		# that is one tab-separated record per line.
		grep "^${PANE_PID} " |
		cut -d' ' -f2-
}

main() {
	exit_safely_if_empty_ppid
	full_command
}
main
