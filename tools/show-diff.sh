#!/bin/bash

set -e

sudo mount -o loop \
	 -t ext4 \
	 ~/.lkvm/default/virt/target.disk \
	 ~/.lkvm/default/virt/target/

sudo find \
	 ~/.lkvm/default/virt/target/root/home/ \
	 -ls

sudo umount ~/.lkvm/default/virt/target/
