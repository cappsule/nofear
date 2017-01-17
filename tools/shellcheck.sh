#!/bin/bash

# Run shellcheck on each shell script.

set -e

find . \
	 -not \( -path ./build -prune \) \
	 -not \( -path ./.git -prune \) \
	 -not \( -path ./rootfs -prune \) \
	 -name "*.sh" \
	 -exec shellcheck '{}' ';'
