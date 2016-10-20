# Why does NoFear require a custom version of kvmtool?

- To allow the guest to access a list of whitelisted host directories (`/bin`,
  `/lib`, `/lib64`, `/opt`, `/sbin` and `/usr`). By default kvmtool shares the
  whole host filesystem.
- To allow different instances of kvmtool to use a stage2 script without race
  condition. This script is a unique temporary file respecting this template:
  `~/.lkvm/[profile]/virt/sandbox-XXXXXXXX` whose path is to the guest through
  the kernel cmdline.



# Is there any console issue?

The console isn't resized automatically yet and must be resized manually with
the `resize` binary. I didn't manage to fix this issue, but pull requests are
welcome.

    user@nofear-default:~$ resize
    COLUMNS=239;
    LINES=69;
    export COLUMNS LINES;



# How to debug the gui?

Launch nofear with `--gui` option but no arguments, and follow the indications:

    $ nofear --gui



# How do I kill properly a VM which doesn't respond?

Use the `stop` command of `kvmtool`:

    $ lkvm-nofear stop --name default

or:

    $ lkvm-nofear stop --all



# What's the current sate of the GUI feature?

The launch hangs sometimes for no reason. We're investigating the issue.
Currently, the Xpra server and Xpra client communicate through a TCP connection.
It isn't optimal at all, and a weird socat trick is used to allow the host to
connect to the guest. According to this
[ticket](http://xpra.org/trac/ticket/983), performances should be better and
implementation cleaner once the VSOCK protocol will be packaged in Linux and
Xpra packages.



# Common error messages

### CPU: vendor_id 'LKVMLKVMLKVM' unknown, using generic init.

The following lines are printed during the boot of the VM:

    CPU: vendor_id 'LKVMLKVMLKVM' unknown, using generic init.
    CPU: Your system may be unstable.
    microcode: no support for this CPU vendor

It's just a warning and they can be ignored. If it bothers you, comment the
following lines in Linux kernel source code
[626, 627](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/tree/arch/x86/kernel/cpu/common.c?id=2b3061c77ce7e429b25a25560ba088e8e7193a67#n626)
and
[633](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/tree/arch/x86/kernel/cpu/microcode/core.c?id=2b3061c77ce7e429b25a25560ba088e8e7193a67#n633).
Then, the kernel must be built again and reinstalled:

    $ ./build.sh bzimage
	$ sudo ./install.sh


### You have requested a TAP device, but creation of one has failed because: Operation not permitted

It seems that you didn't installed `lkvm-nofear` with the install script. To
allow unprivileged user to create TAP devices, give the `net_admin` capability
to `lkvm-nofear`.

    $ sudo setcap cap_net_admin+iep /usr/local/bin/lkvm-nofear


### Warning: Guest memory size 2048MB exceeds host physical RAM size 1983MB

Lower the memory allocated to the VM (`'--mem', '2048',`) in `src/nofear.py`.


### Error: Can't open display: 192.168.33.1:0

Is `--gui` specified on `nofear`'s command-line?


### Error: Could not open /dev/kvm:

It's probably a permission error. Depending of your distro, your user might not
be in the `kvm` group or `/dev/kvm` doesn't have the correct ACL. The ACL of a
file can be modified thanks to `setfacl`. For instance:

    sudo setfacl -m u:user:rw /dev/kvm
