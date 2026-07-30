#!/usr/bin/env bash
# What is running in a pane is the foreground process group of its tty, which is
# the tpgid field of the pane process in /proc. The other strategies all take the
# pane process's children instead and assume there is exactly one: ps.sh and
# pgrep.sh emit a line per child, so a shell with a background job -- a language
# server, an MCP server, anything left running with & -- writes several lines
# into a file that is one tab-separated record per line, and whichever child
# comes first becomes the command the pane is restored with.
#
# Reading tpgid also covers the pane whose own process is the program, with no
# shell in between, which happens whenever a pane is created with a command
# (`tmux split-window btop`, and every pane this plugin restores that way). There
# tpgid equals the pane process's own pgrp, and the other strategies find no
# children at all and save nothing.
#
# Linux only: it reads /proc. On anything else keep the default strategy.

PANE_PID="$1"

exit_safely_if_empty_ppid() {
	if [ -z "$PANE_PID" ]; then
		exit 0
	fi
}

# /proc/<pid>/stat holds comm in parentheses and comm may contain spaces and
# parentheses itself, so fields are counted from after the last ')'.
# There: f3 = pgrp, f6 = tpgid
stat_field() {
	\sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | \cut -d' ' -f"$2"
}

foreground_leader() {
	local tpgid
	tpgid="$(stat_field "$PANE_PID" 6)"
	[ -n "$tpgid" ] && [ "$tpgid" -gt 0 ] || return 1
	# The group leader is the pane process itself when nothing was started in it
	[ "$tpgid" = "$PANE_PID" ] && { echo "$PANE_PID"; return 0; }
	\ps -eo pid=,pgid= | \awk -v g="$tpgid" '$2 == g { print $1; exit }'
}

# An idle shell is not something to restore. A login shell has argv[0] of "-zsh",
# and basename would read the dash as an option, so it is stripped first.
is_pane_shell() {
	local first="${1%% *}" shell
	shell="$(tmux show-option -gqv default-shell)"
	[ -n "$shell" ] || shell="$SHELL"
	[ "$(basename "${first#-}")" = "$(basename "${shell:-/bin/sh}")" ]
}

full_command() {
	local leader command
	leader="$(foreground_leader)" || return 0
	[ -n "$leader" ] || return 0
	command="$(\tr '\0' ' ' < "/proc/$leader/cmdline" 2>/dev/null | \sed 's/ *$//')"
	[ -n "$command" ] || return 0
	is_pane_shell "$command" && return 0
	echo "$command"
}

main() {
	exit_safely_if_empty_ppid
	full_command
}
main
