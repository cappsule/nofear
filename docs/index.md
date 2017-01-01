---
layout: default
---

[NoFear](https://github.com/cappsule/nofear) is a tool developed by
[Quarkslab](https://quarkslab.com) to sandbox applications transparently thanks
to hardware virtualization. More information can be found in the
[No Tears, No Fears blogpost](http://blog.quarkslab.com/no-tears-no-fears.html).

Features:

- Launch any application, cli or GUI, instantaneously in a VM.
- The host filesystem is mounted with an `overlayfs` (write modifications are
  kept in the VM). Some folders of the host filesystem (notably `/etc` and
  `/home`) aren't accessible from the VM. Inside the VM, `/etc` and `/home`
  folders are initialized with a few standard configuration files.
- There's nothing to configure.
- VMs boot on a usual Linux kernel built with the minimum required (no hardware
  driver for example) in a few hundred of milliseconds.

Example for `uname -a`:

    $ nofear uname -a
    Linux nofear-default 4.4.27 #1 SMP Mon Jan 2 10:52:39 CET 2017 x86_64 x86_64 x86_64 GNU/Linux

Launching a GUI application takes a bit more time (a few seconds):

    $ nofear --gui --sound firefox
