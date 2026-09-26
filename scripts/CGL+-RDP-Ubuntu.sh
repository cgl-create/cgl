#!/bin/sh
set -eu

clear
printf '%s\n' "CGL+ LabZ | Ubuntu Remote Desktop Setup"
printf '%s\n\n' "Installing a lightweight desktop and xrdp..."

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf '%s\n' "CGL+: root privileges are required." >&2
    exit 1
  fi
}

as_root apt-get update
as_root apt-get install -y xfce4 xfce4-goodies xrdp

printf '\n%s\n' "Configuring the XFCE desktop for xrdp..."
printf '%s\n' 'startxfce4' > /tmp/cgl-xrdp-start
as_root sh -c 'cat /tmp/cgl-xrdp-start > /etc/skel/.xsession'
rm -f /tmp/cgl-xrdp-start

printf '%s\n' "Setting up the xrdp service..."
as_root adduser xrdp ssl-cert
as_root systemctl enable xrdp
as_root systemctl restart xrdp

printf '\n%s\n' "Remote Desktop Password Setup"
printf '%s\n' "The RDP login uses a Linux user account and its password."
printf '%s\n' "Set or change the password for the current user now."
printf '\n'

if [ "$(id -u)" -eq 0 ]; then
  target_user="$(logname 2>/dev/null || true)"
  [ -n "$target_user" ] || target_user="${SUDO_USER:-root}"
else
  target_user="${USER:-$(id -un)}"
fi

if [ "$target_user" = "root" ]; then
  printf '%s\n' "CGL+: root is not recommended for RDP login." >&2
  printf '%s\n' "Run 'passwd <username>' for a normal user instead." >&2
else
  passwd "$target_user"
fi

printf '\n%s\n' "CGL+ LabZ | Ubuntu RDP Setup Complete"
printf '%s\n' "RDP server: xrdp"
printf '%s\n' "Connect to this Ubuntu system using its IP address and Linux username/password."
printf '%s\n' "Default RDP port: 3389"
