#!/bin/bash

#
# If you don't give a fuck about security, set YOLO environment variable. It
# skips any signature verification.
#
#   YOLO=1 ./build.sh
#

set -e

KVMTOOL_GIT='https://github.com/cappsule/kvmtool.git'
GPG_FINGERPRINT='C7839D20FE954EAD36046E6CFFF0B1815A6C1BAD'

function gpg_hint()
{
	gpg --fingerprint "$GPG_FINGERPRINT" >/dev/null 2>/dev/null && return

	echo ''
	echo "Import NoFear's public key with the following commands:"
	echo '  wget -q -O /tmp/nofear.asc https://keybase.io/cappsule/key.asc'
	echo '  gpg --import /tmp/nofear.asc'
	echo ''
	echo "Please ensure that the fingerprint is actually $GPG_FINGERPRINT:"
	echo '  gpg --with-fingerprint /tmp/nofear.asc'
}

function build_kvmtool()
{
	local dst="$1/kvmtool"

	if [ ! -d "$dst/" ]; then
		git clone "$KVMTOOL_GIT" "$dst"

		if [ -z "$YOLO" ]; then
			# check the GPG signature of last commit
			git -C "$dst/" verify-commit HEAD \
				|| (echo '[-] failed to verify last git commit signature'
					gpg_hint
					exit 1)

			# check the GPG key fingerprint
			git -C "$dst/" verify-commit --raw HEAD \
				|& grep -q "^\[GNUPG:\] VALIDSIG $GPG_FINGERPRINT" \
				|| (echo '[-] unexpected GPG key'; exit 1)
		fi
	fi

	make -C "$dst/"

	cp "$dst/lkvm" "$dst/../"
}

function build_bzimage()
{
	local config="$1"
	local dst="$2"
	local version='linux-4.4.21'

	if [ ! -d "$dst/$version" ]; then
		if [ ! -f "$dst/$version.tar.xz" ]; then
			wget "https://cdn.kernel.org/pub/linux/kernel/v4.x/$version.tar.xz" \
				 -O "$dst/$version.tar.xz"
		fi
		if [ -z "$YOLO" ]; then
			sha256sum --check "$dst/SHA256SUMS"
		fi
		tar -C "$dst/" -xJf "$dst/$version.tar.xz"
	fi

	mkdir -p "$dst/$version-build/"
	cp "$config" "$dst/$version-build/.config"
	KBUILD_OUTPUT="$dst/$version-build/" make -C "$dst/$version/"

	cp "$dst/$version-build/arch/x86_64/boot/bzImage" "$dst/"
}

function build_filesystem()
{
	local dst="$1/rootfs"

	cp -pr 'rootfs/' "$dst/"

	# useful symlinks
	if [ -d /etc/alternatives/ ]; then
		cp -pr /etc/alternatives/ "$dst/etc/"
	fi

	# having these files in the guest filesystem speeds up a lot the launch of
	# graphical applications
	tar cf - /etc/fonts/ /var/cache/fontconfig/ | tar -C "$dst/" -xf -

	if [ -f /etc/ld.so.cache ]; then
		cp -p /etc/ld.so.cache "$dst/etc/"
	fi

	# copy packet manager configuration on Debian-like distros
	local distro=$(lsb_release --short --id 2>/dev/null || true)
	if [ "$distro" == "Ubuntu" ] || [ "$distro" == "Debian" ]; then
		mkdir -p "$dst/var/lib/apt/lists/" \
			  "$dst/var/lib/dpkg/" \
			  "$dst/var/lib/dpkg/alternatives/" \
			  "$dst/var/lib/dpkg/info/" \
			  "$dst/var/lib/dpkg/updates/" \
			  "$dst/var/log/apt/"
		cp -pr /etc/apt/ "$dst/etc/"
		cp -p /var/lib/dpkg/status "$dst/var/lib/dpkg/"
	fi

	# create archive
	tar -C "$dst/" --owner=0 --group=0 -cjf "$dst.tar.bz2" ./
	rm -rf "$dst/"
}

function main()
{
	local build_dir="$(pwd)/build/"

	mkdir -p "$build_dir/"

	while (( "$#" )); do
		echo "[*] building $1 in $build_dir"

		if [ "$1" == 'bzimage' ]; then
			build_bzimage "$build_dir/config" "$build_dir"
		elif [ "$1" == 'filesystem' ]; then
			build_filesystem "$build_dir"
		elif [ "$1" == 'kvmtool' ]; then
			build_kvmtool "$build_dir"
		else
			echo "[-] invalid target $1"
			exit 1
		fi

		shift
	done
}

if [ $# -eq 0 ]; then
	main 'bzimage' 'filesystem' 'kvmtool'
else
	main $*
fi
