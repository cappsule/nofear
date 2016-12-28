---
layout: page
title: Build
permalink: /build/
---

## Project download

    $ git clone https://github.com/cappsule/nofear
    $ cd nofear/


## Build

The `build/` folder contains the files installed on the system. If you don't
trust me, you should compile `kvmtool` and the Linux kernel by yourself with the
`build.sh` script. This script downloads the source of the projects and build
them into the `build/` folder. The default VM filesytem is also generated.

If one or several components are given on the command line, the other components
aren't built. For example:

    $ ./build.sh bzimage
    $ ./build.sh filesystem
    $ ./build.sh kvmtool filesystem

Each component is built by default. The 2 following commands are identical:

    $ ./build.sh
    $ ./build.sh bzimage filesystem kvmtool

The build script verifies the authenticity and/or the integrity of various
components:

- The sha256sum of kernel sources is checked. The goal isn't to verify the
  source code integrity (which is executed in a VMs once compiled), but to avoid
  malicious Makefiles which could compromise the host during the build step.
- The `kvmtool` git repository is reset to a specific revision. If an attacker
  were able to create the same SHA-1 hash with different data, then the
  repository would have been successfully compromised. I would largely prefer to
  verify the signature of the last commit; unfortunately kvmtool commits
  aren't signed at the time.

You should also check the signature of these repository's commit with the
command:

    $ git verify-commit HEAD

If you don't care about security, `YOLO` environment variable skips the
signature checks:

    $ YOLO=1 ./build.sh
