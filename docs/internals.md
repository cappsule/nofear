---
layout: page
title: Internals
permalink: /internals/
---

*This page is an extract from the
[No Tears, No Fears blogpost](http://blog.quarkslab.com/no-tears-no-fears.html).*

The NoFear project relies on 3 open source components: KVM, kvmtool and
Xpra. All the hard work is done by each of these projects, and NoFear is only
the glue (around 500 lines of code) that joins them together.



## Hardware virtualization

### Hypervisor

[KVM](http://www.linux-kvm.org/) is included in mainline Linux kernel as of
2.6.20 and is available by default on major if not all distributions. For
instance, the kernel modules are automatically loaded on Ubuntu 16.04 LTS if the
CPU has hardware virtualization extensions:

    $ lsmod | grep kvm
    kvm_intel             172032  0
    kvm                   540672  1 kvm_intel
    irqbypass              16384  1 kvm

It works great and is known to be the hypervisor behind Google Compute Engine,
with a solid security reputation [^1].


### Hypervisor interface

[QEMU](http://qemu.org) is the default interface for KVM but it doesn't
fulfil exactly our requirements. It provides far more features that needed and
isn't easy to modify. A few people wrote another software entitled kvmtool
which seems more convenient to us. This [LWN article](https://lwn.net/Articles/438182/) explains the origin of the native KVM
tool. It's worth noting that kvmtool is rkt's hypervisor [^2]. Interestingly,
the `--sandbox` option allows the execution of any command line in a new VM
almost transparently.

We think that kvmtool doesn't get all the attention it deserves, but it might be
related to the following observations. The first results for kvmtool on a search
engine redirect to the Clear Containers' GitHub, while the official git
repository is on [git.kernel.org](https://git.kernel.org/cgit/linux/kernel/git/will/kvmtool.git/). Telling
which kvmtool repository is the official one is indeed difficult, and a website
would be great. Incidentally, there's no bugtracker and the mailing-list
is [KVM's](https://www.spinics.net/lists/kvm/), which make contributions
difficult for non-kernel developers in my opinion.

Finally, the C programming language isn't memory safe and can easily lead to
bugs and vulnerabilities; but we're not aware of other alternatives.
[novm](https://github.com/google/novm) is developed in Go but doesn't seem to be
maintained anymore.


## Kernel

A custom Linux kernel is provided to ensure that required configuration options
are enabled, but stock kernels of main distros should also work. Since no
superfluous configuration (eg: driver support) option is enabled, the
`bzImage` is built in less than 3 minutes on a recent computer. It doesn't
matter for end users since the kernel image is provided by NoFear, but it's
appreciated by its developers :)


## Filesystem

### Zero configuration

Cappsule makes use of detailed policies to describe which parts of the
filesystem are shared between the host and the VMs. Unfortunately, these rules
are pretty hard to write and are often broken after software updates. It's thus
tempting for users to use the weakest policy, «unrestricted». Actually, these
policies add a lot of complexity and may not be worth it. That's why we made the
decision to completely get rid of any rules and policy files for NoFear.

During the creation of a new profile, `/etc` and `/home` are initialized
with default configuration files (eg: `/etc/passwd`, `/home/user/.bashrc`).
Once a VM is running, the following folders are shared with the host in
read-only mode: `/bin`, `/lib`, `/lib64`, `/opt`, `/sbin` and
`/usr`. It allows software installed in the host to be directly available to
the VMs, but sensitive folders (`/etc` and `/home`) are not available not to
leak any information to the guests.

Once again, we rely on kvmtool with a small patch to restrict which host folders
can be shared. We found a few security issues in kvmtool's implementation of
virto 9p [^3] but they should be fixed soon, as we sent a patch series upstream
a few days ago.

### Profiles

Changes to the filesystem are kept from one execution to another. Profiles are
stored in `~/.lkvm/[profile-name]/` and contain every change made to the
filesystem.  If no `-p/--profile` argument is given on the command line, the
`default` profile is used. A profile can be deleted with `-d/--delete`
argument.

Technically, a sparse file is created during the creation of a new profile
thanks to the `dd`'s `seek` option:

    # dd status=none if=/dev/zero of=/virt/target.disk bs=1 count=0 seek=1G

This file, `/virt/target.disk`, is shared between the host and the guest. Once
created, an ext4 filesystem is built, and an overlay filesystem ensures that
each modification is kept:

    # mkfs.ext4 -q /virt/target.disk
    # mount -o loop /virt/target.disk /virt/target
    # mount -n -t overlay overlay \
          /virt/target/overlay \
          -o lowerdir=/host,\
             upperdir=/virt/target/rw/upperdir,\
             workdir=/virt/target/rw/workdir

All these operations are done *inside* the VM.


## GUI

[Xpra](https://xpra.org/) is a persistent remote display server and client for
forwarding applications and desktop screens which works like a X11
proxy. It's under active development and sound features (microphone and
speakers) are supported. Available on most distros and working out of the box,
it's no coincidence that [Firejail](https://firejail.wordpress.com/) and
[Subgraph OS](https://subgraph.com/sgos/) rely on Xpra for their GUI.

However, it didn't receive as much attention as [Qubes OS GUI](https://www.qubes-os.org/doc/gui/)
from a security point of view. Some
tickets (eg: [#11155](http://xpra.org/trac/changeset/11155/xpra) and
[#1217](https://xpra.org/trac/ticket/1217)) give the impression that some parts of
the project need a more thorough review. Hopefully, memory corruption bugs
should be almost inexistent since Xpra is mostly developed in Python.

About performances, they're acceptable at the time and should even improve when
[virtio-sock](http://xpra.org/trac/ticket/983) will be available in distros'
kernels.


## Network

Network works out of-the-box with kvmtool which supports several network
modes. The *user* mode is used by default but it seems quite buggy and
connection sometimes hangs for no reason. Thanks to virto-net, performances of
*tap* mode are much better and it's also way more reliable.

In tap mode, root privileges are required during the install to:

- set the `cap_net_admin` capability to the kvmtool binary to allow
  unprivileged user to launch VMs with network support
- enable IP forwarding with `sysctl -w net.ipv4.ip_forward=1`
- enable NAT with `iptables -t nat -A POSTROUTING -j MASQUERADE`


## Distro Dependencies Issues

While the concepts behind NoFear are straightforward, slight differences across
distros make it difficult to create a generic package. Below are the differences
that we encountered during the beta-test.

The filesystem needs to be customized since usual packages are installed
differently across Linux distros. For instance, on Debian-like systems a lot of
usual files are actually symlinks in `/etc/alternatives/`
([man update-alternatives](http://manpages.ubuntu.com/manpages/trusty/en/man8/update-alternatives.8.html)):

    $ ls -l /etc/alternatives
    [...]
    lrwxrwxrwx   1 root root    29 Jul 19 09:27 google-chrome -> /usr/bin/google-chrome-stable
    lrwxrwxrwx   1 root root    15 Jul 18 11:18 nc -> /bin/nc.openbsd
    lrwxrwxrwx   1 root root    18 Jul 18 11:21 vim -> /usr/bin/vim.basic

If these symlinks aren't present in the VM filesystem, those commands are
obviously not found. In a similar way, font files are located in different
folders across distros.  On Gentoo, `mount` fails to run (as root!) in the VM
with a *permission denied* error, and we still need to investigate this issue.

Concerning Xpra, it works out of the box on most distros but the packaged
version is often out-of-date. Xpra configuration varies widly between
versions. For instance, `--daemon` option doesn't exist on Ubuntu 15.10 (Xpra
v0.14.25) while it's supported on Ubuntu 16.04 (xpra v0.15.8). On Debian, the
default configuration file seems to be broken...


## References

[^1]: [Security Hardening of KVM](https://lwn.net/Articles/619332/)
[^2]: [rkt, a security-minded, standards-based container engine](https://coreos.com/rkt/)
[^3]: [kvmtool: vulnerabilities in 9p virtio](http://www.spinics.net/lists/kvm/msg130505.html)
