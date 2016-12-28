---
layout: page
title: Install
permalink: /install/
---

NoFear works out of the box on Ubuntu 16.04 but may require a few tweaks on
other distros. Please give a look at the various patches in the
[distro/](https://github.com/cappsule/nofear/tree/master/distro) folder. If you
encounter any issue, bug reports and pull requests are more than welcome!


## Requirements

Xpra and the following packages must be installed for the `--gui` switch
support:

    $ sudo apt install socat xpra

Regarding sound support, the following packages must be installed on Ubuntu:

    $ sudo apt install python-gst0.10 gstreamer0.10-plugins-base gstreamer0.10-plugins-good gstreamer0.10-pulseaudio



## Install

Download the repository and the release archive:

    $ git clone https://github.com/cappsule/nofear
    $ cd nofear/
    $ ./dl-release.sh

Filesystem has to be built:

    $ ./build.sh filesystem

Required files are copied into `/usr/local/bin/` and `/usr/local/share/nofear/`
with the command:

    $ sudo ./install.sh

The project can be uninstalled with the following command:

    $ sudo ./install.sh --uninstall


### Network

The network is configured in *tap* mode by default and required these commands
to be executed in the host:

    $ sudo sysctl -w net.ipv4.ip_forward=1
    $ sudo iptables -t nat -A POSTROUTING -j MASQUERADE
