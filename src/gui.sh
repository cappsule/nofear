#!/bin/bash

# This script is meant to be executed from a VM to start a graphical application
# through Xpra.

set -e

function xpra_cleanup()
{
	rm -f ~/.Xauthority*
	rm -rf ~/.xpra/ ~/.dbus/
}

function run_xpra()
{
	local xpra_port="$1"
	shift
	local cmd="$*"

	GUEST_HOSTNAME=$(hostname)
	GUEST_DISPLAY=100
	GATEWAY=$(ip route | grep default | cut -d ' ' -f 3)
	SOCAT_CMD="socat UNIX-CONNECT:$HOME/.xpra/$GUEST_HOSTNAME-$GUEST_DISPLAY,retry=3 TCP-CONNECT:$GATEWAY:$xpra_port"

	/usr/bin/xpra start ":$GUEST_DISPLAY" \
				  --daemon=no \
				  --exit-with-children \
				  --start="$SOCAT_CMD" \
				  --start-child="$cmd"
}

function main()
{
	local xpra_port

	# this trick avoids to have to specify the port on the command line
	# shellcheck disable=SC2153
	if [ -n "$XPRA_PORT" ]; then
		xpra_port="$XPRA_PORT"
	elif [ $# -ne 0 ]; then
		xpra_port="$1"
		shift
	else
		echo "Usage: $0 <xpra_port> <cmd...>"
		exit 1
	fi

	if [ $# -eq 0 ]; then
		echo "[*] spawning shell in gui mode"
		echo "    run the following command to launch a graphical process:"
		echo "    $0 <cmd...>"
		XPRA_PORT="$xpra_port" bash -i
		exit 0
	fi

	xpra_cleanup
	run_xpra "$xpra_port" "$@"
}

main "$@"
