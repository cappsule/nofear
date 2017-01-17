#!/bin/bash

# This script is meant to be executed from a VM to initialize the network and
# create a few devices required by the next steps.

set -e

function init_filesystem()
{
	# /etc/fstab is required by dhclient
	# /etc/mtab is required by mkfs.ext4
	for f in /etc/fstab /etc/mtab; do
		touch "$f"
	done

	if [ ! -b /dev/loop0 ]; then
		mount -t tmpfs tmpfs /dev/
		mknod /dev/loop0 b 7 0
		mknod -m 666 /dev/zero c 1 5
	fi
}

function init_network()
{
	local hostname="$1"

	hostname "nofear-$hostname"
	ifconfig lo up

	# XXX: I didn't a find a better way to guess network mode
	if ifconfig eth0 | grep HWaddr | grep -q 02:15:15:15:15:15; then
		# network in mode=user
		dhclient eth0
	else
		# network in mode=tap
		ifconfig eth0 192.168.33.15
		route add default gw 192.168.33.1
	fi

	echo 'nameserver 8.8.8.8' > /etc/resolv.conf
}

function main()
{
	local dir
	dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

	local hostname="$1"
	shift

	# If $hostname is too long, hostname command fails. Truncate $hostname to 16
	# characters.
	hostname=${hostname:0:16}

	init_filesystem
	init_network "$hostname"

	exec "$dir/overlayfs.sh" "$@"
}

main "$@"
