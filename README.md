NoFear is a tool developed by [Quarkslab](http://quarkslab.com) to sandbox
applications transparently thanks to hardware virtualization.

It works out of the box on Ubuntu 16.04 but may require a few tweaks on other
distros. Please give a look at the various patches in the `distro/` folder. If
you encounter any issue, bug reports and pull requests are more than welcome!



# tl;dr

    $ git clone https://github.com/cappsule/nofear
    $ cd nofear/
    $ ./build.sh filesystem
    $ sudo ./install.sh
    $ sudo apt install socat xpra
    $ sudo sysctl -w net.ipv4.ip_forward=1
    $ sudo iptables -t nat -A POSTROUTING -j MASQUERADE

    $ nofear
    $ nofear ps fauxw
    $ nofear --gui xclock -update 1
    $ nofear --gui --sound firefox



# Goals

- Launch any application, cli or GUI, instantaneously in a VM.
- The host filesystem is mounted with an `overlayfs` (write modifications are
  kept in the VM). Some folders of the host filesystem (notably `/etc` and
  `/home`) aren't accessible from the VM. Inside the VM, `/etc` and `/home`
  folders are initialized with a few standard configuration files.
- There's nothing to configure.
- VMs boot on a usual Linux kernel built with the minimum required (no hardware
  driver for example) in a few hundred of milliseconds.



# What's the difference with Cappsule?

Regarding virtualization, [Cappsule](https://cappsule.github.io) introduced the
concept of *on the fly virtualization* with a custom hypervisor; whereas NoFear
makes use of [KVM](https://www.linux-kvm.org/) included in mainline Linux
kernel.

Concerning dependencies, Cappsule requires a custom Ubuntu configuration and a
specific Linux kernel version. Any change to the Linux kernel is prone to break
the hypervisor or the VMs. NoFear aims at being distro-independent, requiring
software distributed through the distro packages.



# Project download

    $ git clone https://github.com/cappsule/nofear



# Build

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

- the signature of the last `kvmtool` is checked (you must have my
  [public key](https://keybase.io/cappsule/key.asc))
- the sha256sum of kernel sources is checked. The goal isn't to verify the
  source code integrity (which is executed in a VMs once compiled), but to avoid
  malicious Makefiles which could compromise the host during the build step.

You should also check the signature of these repository's commit with the
command:

    $ git verify-commit HEAD

If you don't care about security, `YOLO` environment variable skips the
signature checks:

    $ YOLO=1 ./build.sh



# Requirements

Xpra and the following packages must be installed for the `--gui` switch
support:

    $ sudo apt install socat xpra

Regarding sound support, the following packages must be installed on Ubuntu:

    $ sudo apt install python-gst0.10 gstreamer0.10-plugins-base gstreamer0.10-plugins-good gstreamer0.10-pulseaudio



# Install

Filesystem has to be built:

    $ ./build.sh filesystem

Required files are copied into `/usr/local/bin/` and `/usr/local/share/nofear/`
with the command:

    $ sudo ./install.sh

If you don't want to install these files as `root`, the following files have to
be edited:

- `install.sh`: `$BIN` and `$SHARED` environment variable
- `src/nofear.py`: `NOFEAR_DIR` variable
- `src/overlayfs.sh`: `tar` command

The project can be uninstalled with the following command:

    $ sudo ./install.sh --uninstall


## Network

The network is configured in *tap* mode by default and required these commands
to be executed in the host:

    $ sudo sysctl -w net.ipv4.ip_forward=1
    $ sudo iptables -t nat -A POSTROUTING -j MASQUERADE



# Usage

## Execution of a shell in a VM

    $ nofear

During the first launch, the `default` profile is created (in the
`~/.lkvm/default/` folder). The profile can also be specified with
`-p` or `--profile` argument:

    $ nofear --profile test

Use `--help` to get some help:

    $ nofear --help


## Usage examples

    $ nofear ps fauxwww
    $ nofear --profile test --gui evince
    $ nofear --gui --sound firefox



# Contributions

Please report bugs through
[GitHub's issue interface](https://github.com/cappsule/nofear/issues). Pull
requests are always welcome.
