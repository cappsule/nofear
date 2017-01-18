---
layout: page
title: Build
permalink: /build/
---

## Project download

    $ git clone https://github.com/cappsule/nofear
    $ cd nofear/

You should check the last commit signature with the command:

    $ git verify-commit HEAD

NoFear's GPG key can be downloaded
([key.asc](https://keybase.io/cappsule/key.asc)) from
[keybase.io](https://keybase.io/cappsule) (username: `cappsule`, fingerprint:
`C783 9D20 FE95 4EAD 3604 6E6C FFF0 B181 5A6C 1BAD`).



## Build

The build step is required to generate a default VM filesystem specific to the
distribution. If you don't trust me you should also compile `kvmtool` and the
Linux kernel by yourself; otherwise `bzImage` and `lkvm` are automatically
downloaded from the [release page](https://github.com/cappsule/nofear/releases)
thanks to `dl-release.sh`.

The `build.sh` script downloads the source of the different components and build
them into the `build/` folder. Each component (`bzimage`, `filesystem` and
`kvmtool`) is built by default. If one or several components are given on the
command line, the other components aren't built. Usage examples:

    $ ./build.sh
    $ ./build.sh filesystem kvmtool


### Filesystem

The following command creates a filesystem archive from `rootfs/` and adds a few
files specific to the distribution:

    $ ./build.sh filesystem

The resulting archive is the initial filesystem of the VMs.


### kvmtool

The following command applies patches from `patches/kvmtool/` and builds the
`lkvm` binary:

    $ ./build.sh kvmtool

The `kvmtool` git repository is reset to a specific revision before being
compiled. If an attacker were able to create the same SHA-1 hash with different
data, then the repository would have been successfully compromised. I would
largely prefer to verify the signature of the last commit; unfortunately kvmtool
commits aren't signed at the time.


### Kernel

The following command applies patches from `patches/kernel/` and builds the VM
kernel:

    $ ./build.sh bzimage

The sha256sum of kernel sources is checked. The goal isn't to verify the source
code integrity (which is executed in a VMs once compiled), but to avoid
malicious Makefiles which could compromise the host during the build step.
