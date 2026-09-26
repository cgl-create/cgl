#!/bin/sh
set -eu

clear
printf '%s\n' "CGL+ LabZ | Raspberry Pi OS Remote Desktop Setup"
printf '%s\n\n' "Installing xrdp for RDP remote access..."

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
as_root apt-get install -y xrdp

printf '\n%s\n' "Setting up the xrdp service..."
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

printf '\n%s\n' "CGL+ LabZ | Raspberry Pi OS RDP Setup Complete"
printf '%s\n' "RDP server: xrdp"
printf '%s\n' "Connect to this Pi using its IP address and the Linux username/password."
printf '%s\n' "Default RDP port: 3389"
