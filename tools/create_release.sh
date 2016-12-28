#!/bin/bash

# Create release archive of binary files.

set -e

tar -cjvf build/nofear.tar.bz2 \
	--owner=0 --group=0 \
	build/bzImage \
	build/lkvm

sha256sum build/nofear.tar.bz2 > build/SHA256SUMS.release
