---
layout: page
title: Usage
permalink: /usage/
---

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


## Shared folder

A folder can be shared between host and guest thanks to `-f` or
`--shared-folder` argument. For example, to share `~/code/project` with the
guest:

    $ nofear --shared-folder ~/code/project

The shared folder is mounted in the guest under `/shared`.
