---
layout: page
title: tl;dr
permalink: /tldr/
---

## Install

    git clone https://github.com/cappsule/nofear
    cd nofear/
    ./dl-release.sh
    ./build.sh filesystem
    sudo ./install.sh
    sudo apt install socat xpra
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo iptables -t nat -A POSTROUTING -j MASQUERADE


## Run

    nofear
    nofear ps fauxw
    nofear --gui xclock -update 1
    nofear --gui --sound firefox
