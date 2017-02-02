#!/bin/bash

# This script is meant to be executed from a VM to mount a disk image as an
# overlay filesystem. This disk image is shared with the host filesystem.

set -e

function create_files
{
	local target=$1

	tar -C "$target/" -xjf /usr/local/share/nofear/rootfs.tar.bz2

	chown -R 2000:2000 "$target/home/user"

	echo "127.0.1.1 $(hostname)" >> "$target/etc/hosts"

	mkdir -p "$target/dev"
	mknod -m 666 "$target/dev/null" c 1 3
	mknod -m 666 "$target/dev/zero" c 1 5
	mknod -m 444 "$target/dev/random" c 1 8
	mknod -m 444 "$target/dev/urandom" c 1 9
	mknod -m 666 "$target/dev/console" c 5 1
	mknod -m 666 "$target/dev/ptmx" c 5 2
	mknod -m 666 "$target/dev/tty" c 5 0
	mknod -m 620 "$target/dev/tty0" c 4 0
	mknod -m 620 "$target/dev/tty1" c 4 1
	mknod -m 620 "$target/dev/tty2" c 4 2

	chown 0:5 "$target/dev/console" \
		  "$target/dev/tty0" \
		  "$target/dev/tty1" \
		  "$target/dev/tty2"

	mkdir --mode=0775 "$target/var/run/screen/"
	chown 0:43 "$target/var/run/screen/"
}

function mount_loop
{
	local unitialized=0
	local image=$1
	local target=$2

	if [ ! -f "$image" ]; then
		# create a sparse file (pay attention to the 'seek' parameter)
		dd status=none if=/dev/zero of="$image" bs=1 count=0 seek=1G
		mkfs.ext4 -q "$image"
		mkdir -p "$target"
		unitialized=1
	fi

	# If /sys is mounted, we get the following errors whenever mount or
	# umount are executed:
	#
	#   mount: /proc/self/mountinfo: parse error: ignore entry at line 3.
	#   umount: /proc/self/mountinfo: parse error: ignore entry at line 3.
	#
	# Because of the following line:
	#
	#   11 9 0:12 / /sys rw,relatime - sysfs  rw
	umount /sys || true

	mount -o loop "$image" "$target"

	if [ "$unitialized" -eq "1" ]; then
		mkdir -p "$target/root"
		create_files "$target/root"
	fi
}

function mount_overlay
{
	local target=$1

	mkdir -p "$target"
	mkdir -p "$target/ro"
	mkdir -p "$target/overlay"
	mkdir -p "$target/rw"

	mkdir -p "$target/rw/workdir"
	mkdir -p "$target/rw/upperdir"

	mount -n -t overlay overlay "$target/overlay" \
		  -o lowerdir=/host,upperdir="$target/rw/upperdir,workdir=$target/rw/workdir,noatime"
}

function mount_persistent_dirs
{
	local target=$1

	for d in dev etc home root sys tmp var; do
		mkdir -p "$target/root/$d"
		mount --bind "$target/root/$d" "$target/overlay/$d"
	done

	for d in pts shm; do
		mkdir -p "$target/overlay/dev/$d"
	done

	mount -t proc proc "$target/overlay/proc"
	mount -t devpts -o gid=4,mode=620 none "$target/overlay/dev/pts"
	mount -t tmpfs tmpfs "$target/overlay/dev/shm"
	mount -t tmpfs tmpfs "$target/overlay/tmp"

	# get rid of the following error:
	# _XSERVTransmkdir: ERROR: euid != 0,directory /tmp/.X11-unix will not be created.
	mkdir -p --mode=1777 "$target/overlay/tmp/.X11-unix"
}

function bind_virt
{
	local target=$1

	mkdir -p "$target/overlay/virt"
	mount --bind /virt "$target/overlay/virt"
}

function mount_shared_folder
{
	local target=$1
	local dir=$2

	if [ -n "$dir" ]; then
		mkdir -p "$target/overlay/$dir"
		mount -t 9p nofear-shared "$target/overlay/$dir" -o trans=virtio,version=9p2000.L
	fi
}

function run_command
{
	local target=$1
	local root=$2
	shift 2

	export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	export SHELL=/bin/bash

	# ensure that chroot doesn't return an error even if the command doesn't
	# return 0 (otherwise the script exits right away without calling cleanup)
	if "$root"; then
		export HOME=/root
		chroot "$target/overlay" "$@" \
			|| true
	else
		export HOME=/home/user
		#resize
		chroot --userspec=user:user "$target/overlay" "$@" \
			|| true
	fi
}

function cleanup
{
	local target=$1

	sync
	umount --recursive "$target"
}

function main()
{
	local image='/virt/target.disk'
	local target='/virt/target/'

	mount_loop "$image" "$target"
	mount_overlay "$target"
	mount_persistent_dirs "$target"
	bind_virt "$target"
	mount_shared_folder "$target" "$NOFEAR_SHARED"

	run_command "$target" false "$@"

	cleanup "$target"
}

main "$@"
