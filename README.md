# CGL+

CGL+ is a universal Linux package and script manager. It is designed as a Homebrew-style command layer while still using the native package manager underneath.

## Linux support

CGL detects and works with these native package managers:

- Debian / Ubuntu / Raspberry Pi OS: `apt`
- Fedora / modern RHEL-family systems: `dnf`
- Older RHEL-family systems: `yum`
- Arch Linux: `pacman`
- openSUSE / SUSE: `zypper`
- Alpine Linux: `apk`

The CGL executable is a POSIX shell program and is therefore not tied to one Linux distribution or CPU architecture.

## Install

For Debian-family systems, the planned package repository will provide:

    sudo apt update
    sudo apt install cgl

For other distributions, CGL can be bootstrapped without a distribution package by downloading `cgl` from this repository and installing it under `/usr/local/bin`:

    git clone https://github.com/cgl-create/cgl.git
    cd cgl
    sudo ./install.sh

A future signed CGL repository will provide native packages and repository setup for additional distributions.

## Commands

    cgl version
    cgl run CGL+-RPiOS-Update.sh
    cgl update
    cgl update -os rpi
    cgl install <package>
    cgl remove <package>
    cgl search <term>
    cgl list
    cgl doctor

## Design

CGL does not replace APT, DNF, Pacman, Zypper, APK, or other native package managers. It detects the host distribution's package manager and delegates package operations to it. CGL+ packages and scripts can be added independently of the underlying operating system.

The intended Debian-family repository endpoint is `https://packages.crazygamelabs.co.uk`. It must be signed and published before users should add it to APT.
