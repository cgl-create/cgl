# CGL+

CGL+ is a universal Linux package and script manager. It provides a Homebrew-style command layer while continuing to use the native package manager underneath.

## Linux support

CGL detects and works with these native package managers:

- Debian / Ubuntu / Raspberry Pi OS: `apt`
- Fedora / modern RHEL-family systems: `dnf`
- Older RHEL-family systems: `yum`
- Arch Linux: `pacman`
- openSUSE / SUSE: `zypper`
- Alpine Linux: `apk`

The CGL executable is a POSIX shell program and is not tied to one Linux distribution or CPU architecture.

## Debian / Ubuntu / Raspberry Pi OS installation

The signed CGL+ APT repository is live at:

    https://packages.crazygamelabs.co.uk

For a secure first-time setup, install the repository keyring and source configuration with the included bootstrap script. The script pins the expected CGL+ signing-key fingerprint before configuring APT:

    git clone https://github.com/cgl-create/cgl.git
    cd cgl
    sudo sh ./scripts/setup-apt.sh

Then install CGL+ normally:

    sudo apt update
    sudo apt install cgl

After that, upgrades use the same signed repository:

    sudo apt update
    sudo apt upgrade cgl

The repository key fingerprint currently expected by the bootstrap script is:

    60B4D386243F10FBAA2B95C0D2EC0C12FD8D39CC

Do not use `[trusted=yes]` for normal installations. That option disables the normal APT signature trust check and is only useful for temporary repository diagnostics.

### One-command APT bootstrap

If you have reviewed the bootstrap script and want to run it directly from GitHub:

    curl -fsSL https://raw.githubusercontent.com/cgl-create/cgl/main/scripts/setup-apt.sh | sudo sh

The script downloads the public key over HTTPS, verifies its fingerprint, installs it under `/usr/share/keyrings`, and writes a `signed-by=` APT source entry. It does not install the `cgl` package itself.

## Other Linux distributions

For Fedora, RHEL-family, Arch, openSUSE, and Alpine systems, CGL can be bootstrapped without a CGL distribution package:

    git clone https://github.com/cgl-create/cgl.git
    cd cgl
    sudo sh ./install.sh

This installs the CGL CLI and bundled scripts under `/usr/local`.

CGL then delegates package operations to the host's native package manager.

## Commands

    cgl version
    cgl help
    cgl run CGL+-RPiOS-Update.sh
    cgl update
    cgl update -os rpi
    cgl update -os ubuntu
    cgl install rdp -os rpi
    cgl install rdp -os ubuntu
    cgl autoupdate
    cgl autoupdate on
    cgl autoupdate off
    cgl install <package>
    cgl remove <package>
    cgl search <term>
    cgl list
    cgl doctor

## CGL+ Browser RDP

Install the remote desktop gateway with:

    sudo cgl install rdp -os rpi

or:

    sudo cgl install rdp -os ubuntu

The RDP setup provides a CGL+-skinned browser remote desktop through noVNC on port `1350`.

The installer is designed for systems that already have a WayVNC session. It shares the **current Wayland desktop session** instead of creating another desktop. It does not install XFCE or TigerVNC.

The installer also enables Avahi so the browser can normally reach the machine using its mDNS hostname:

    http://<hostname>.local:1350

The CGL+ browser screen has a custom CGL+ login page. It asks for the Linux username and password and passes those credentials to WayVNC's PAM authentication layer.

The browser gateway uses noVNC and websockify. WayVNC remains bound to localhost on port 5900, while websockify exposes the browser gateway on port 1350.

Port 1350 is intended for a trusted LAN in this configuration. The browser gateway is HTTP/WebSocket by default, while the VNC authentication channel uses WayVNC's TLS authentication. HTTPS/WSS should still be added before exposing the browser UI outside a trusted network.

Note: WayVNC is intended for wlroots-based Wayland compositors.

## Design

CGL does not replace APT, DNF, Pacman, Zypper, APK, or other native package managers. It detects the host distribution's package manager and delegates package operations to it. CGL+ packages and scripts can be added independently of the underlying operating system.

The Debian-family CGL+ repository is signed and published at `https://packages.crazygamelabs.co.uk`.
