#!/bin/bash

# Download release archive from GitHub's website, check its sha256sum and
# extract it.

set -e

VERSION=v0.1.1
RELEASE_URL=https://github.com/cappsule/nofear/releases/download
RELEASE_FILE=nofear.tar.bz2

function download_release()
{
	wget "$RELEASE_URL/$VERSION/$RELEASE_FILE" -O "build/$RELEASE_FILE"

	sha256sum --check build/SHA256SUMS.release || \
		( echo "[-] The sha256sum of $RELEASE_FILE is invalid!"
		  echo "[-] Stop the installation and fix this issue."
		  exit 1 )
}

function main()
{
	# if release file is outdated or corrupted, try to download it again
	sha256sum --check --quiet build/SHA256SUMS.release || download_release

	tar xjvf "build/$RELEASE_FILE"
}

main $*
