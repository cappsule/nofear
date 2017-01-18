---
layout: page
title: FAQ
permalink: /faq/
---

## What's the difference with Cappsule?

Regarding virtualization, [Cappsule](https://cappsule.github.io) introduced the
concept of *on the fly virtualization* with a custom hypervisor; whereas NoFear
makes use of [KVM](https://www.linux-kvm.org/) included in mainline Linux
kernel.

Concerning dependencies, Cappsule requires a custom Ubuntu configuration and a
specific Linux kernel version. Any change to the Linux kernel is prone to break
the hypervisor or the VMs. NoFear aims at being distro-independent, requiring
software distributed through the distro packages.



## Why does NoFear require a custom version of kvmtool?

- To allow the guest to access a list of whitelisted host directories (`/bin`,
  `/lib`, `/lib64`, `/opt`, `/sbin` and `/usr`). By default kvmtool shares the
  whole host filesystem.
- To allow different instances of kvmtool to use a stage2 script without race
  condition. This script is a unique temporary file respecting this template:
  `~/.lkvm/[profile]/virt/sandbox-XXXXXXXX` whose path is given to the guest
  through the kernel cmdline.



## How to debug the gui?

Launch nofear with `--gui` option but no arguments, and follow the indications:

    $ nofear --gui



## How do I kill properly a VM which doesn't respond?

Use the `stop` command of `kvmtool`:

    $ lkvm-nofear stop --name default

or:

    $ lkvm-nofear stop --all



## What's the current state of the GUI feature?

The launch hangs sometimes for no reason. We're investigating the
[issue](https://github.com/cappsule/nofear/issues/4). Currently, the Xpra server
and Xpra client communicate through a TCP connection. It isn't optimal at all,
and a weird socat trick is used to allow the host to connect to the guest.
According to this [ticket](http://xpra.org/trac/ticket/983), performances should
be better and implementation cleaner once the VSOCK protocol will be packaged in
Linux and Xpra packages.



## Common error messages

#### You have requested a TAP device, but creation of one has failed because: Operation not permitted

It seems that you didn't installed `lkvm-nofear` with the install script. To
allow unprivileged user to create TAP devices, give the `net_admin` capability
to `lkvm-nofear`.

    $ sudo setcap cap_net_admin+iep /usr/local/bin/lkvm-nofear


#### Warning: Guest memory size 2048MB exceeds host physical RAM size 1983MB

Lower the memory allocated to the VM (`'--mem', '2048',`) in `src/nofear.py`.


#### Error: Can't open display: 192.168.33.1:0

Is `--gui` specified on `nofear`'s command-line?


#### Error: Could not open /dev/kvm:

It's probably a permission error. Depending of your distro, your user might not
be in the `kvm` group or `/dev/kvm` doesn't have the correct ACL. The ACL of a
file can be modified thanks to `setfacl`. For instance:

    sudo setfacl -m u:user:rw /dev/kvm
