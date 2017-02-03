#!/bin/bash

# This script is meant to be executed from a VM to start a graphical application
# through Xpra.

set -e

function xpra_cleanup()
{
	rm -f ~/.Xauthority*
	rm -rf ~/.xpra/ ~/.dbus/
}

function setup_shmem()
{
	local pci_id

	sudo mount -t sysfs sysfs /sys/

	pci_id=$(lspci | grep 'Inter-VM shared memory' | cut -d ' ' -f 1)
	echo 1 | sudo tee "/sys/devices/pci0000:00/0000:$pci_id/enable" >/dev/null
	sudo chmod 0666 "/sys/devices/pci0000:00/0000:$pci_id/resource2"

	export GUEST_MMAP_FILE_PATH="/sys/devices/pci0000:00/0000:$pci_id/resource2"
	export LD_PRELOAD='/usr/local/share/nofear/libmmap.so'
}

function run_xpra()
{
	local xpra_port="$1"
	shift
	local cmd="$*"

	local guest_hostname
	local gateway
	local guest_display=100

	# build socat command
	gateway=$(ip route | grep default | cut -d ' ' -f 3)
	guest_hostname=$(hostname)
	local socat_cmd="socat UNIX-CONNECT:$HOME/.xpra/$guest_hostname-$guest_display,retry=3 TCP-CONNECT:$gateway:$xpra_port"

	/usr/bin/xpra start ":$guest_display" \
				  --daemon=no \
				  --exit-with-children \
				  --start="$socat_cmd" \
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
	setup_shmem
	run_xpra "$xpra_port" "$@"
}

main "$@"
