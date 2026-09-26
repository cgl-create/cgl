# CGL+

CGL+ Debian package repository and CLI.

The first package is `cgl`, a Homebrew-inspired package and script manager for Debian-based systems.

## Build

    chmod +x scripts/*.sh
    ./scripts/build-deb.sh

## Commands

    cgl version
    cgl run CGL+-RPiOS-Update.sh
    cgl update -os rpi
    cgl install <package>
    cgl remove <package>
    cgl search <term>
    cgl list
    cgl doctor

The intended APT endpoint is https://packages.crazygamelabs.co.uk. The repository must be signed before users can safely install with `sudo apt install cgl`.