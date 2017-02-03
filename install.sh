#!/bin/bash

set -e

BIN=/usr/local/bin
SHARE=/usr/local/share/nofear

function install()
{
	if [ ! -f build/rootfs.tar.bz2 ]; then
	   echo "[-] build/rootfs.tar.bz2 doesn't exist"
	   echo '    run ./build.sh filesystem'
	   exit 1
	fi

	cp src/nofear.py "${BIN}/"
	cp build/lkvm "${BIN}/lkvm-nofear"
	ln -sf nofear.py "${BIN}/nofear"

	# XXX: not sure that's a good idea, but it fixes error related to tun
	# permissions when running lkvm with --network mode=tap. We might use
	# fd option?
	setcap cap_net_admin+iep "${BIN}/lkvm-nofear"

	mkdir -p "${SHARE}/"
	cp build/bzImage \
	   build/rootfs.tar.bz2 \
	   src/base.sh \
	   src/gui.sh \
	   src/overlayfs.sh \
	   src/xpra.conf \
	   distro/mmap/libmmap.so \
	   "${SHARE}/"

	echo '[+] nofear installed'
}

function uninstall()
{
	rm -f "${BIN}/nofear" \
	   "${BIN}/nofear.py" \
	   "${BIN}/lkvm-nofear"
	rm -f "${SHARE}/bzImage" \
	   "${SHARE}/rootfs.tar.bz2" \
	   "${SHARE}/base.sh" \
	   "${SHARE}/gui.sh" \
	   "${SHARE}/overlayfs.sh" \
	   "${SHARE}/xpra.conf" \
	   "${SHARE}/libmmap.so"
	if [ -d "${SHARE}/" ]; then
		rmdir "${SHARE}/"
	fi

	echo '[+] nofear uninstalled'
}

function main()
{
	if [ "$(id -u)" -ne 0 ]; then
		echo "[-] root privileges required"
		exit 1
	fi

	if [ $# -eq 1 ] && ( [ "x$1" == "x-u" ] || [ "x$1" == "x--uninstall" ] ); then
		uninstall
	elif [ $# -eq 0 ] || ([ $# -eq 1 ] && ( [ "x$1" == "x-i" ] || [ "x$1" == "x--install" ] )); then
		install
	else
		echo "Usage: $0 [-i|--install] [-u|--uninstall]"
		exit 1
	fi
}

main "$@"
