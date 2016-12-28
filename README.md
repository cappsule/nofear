NoFear is a tool developed by [Quarkslab](http://quarkslab.com) to sandbox
applications transparently thanks to hardware virtualization. More information
can be found in the [website](https://cappsule.github.io/nofear/).

If you're too impatient to read the doc, install it with the following commands:

    git clone https://github.com/cappsule/nofear
    cd nofear/
    ./dl-release.sh
    ./build.sh filesystem
    sudo ./install.sh
    sudo apt install socat xpra
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo iptables -t nat -A POSTROUTING -j MASQUERADE

And you're ready to use it:

    nofear
    nofear ps fauxw
    nofear --gui xclock -update 1
    nofear --gui --sound firefox
