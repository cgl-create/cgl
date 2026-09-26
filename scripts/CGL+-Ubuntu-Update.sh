#!/bin/sh
set -eu

clear
printf '%s\n' "CGL+ LabZ | Ubuntu Update Sequence Initiated"
printf '%s\n\n' "Preparing your Ubuntu system..."

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

printf '%s\n' "[1/7] Updating package index..."
as_root apt-get update
printf '%s\n\n' "Package index updated."

printf '%s\n' "[2/7] Installing Neofetch..."
as_root apt-get install -y neofetch

printf '%s\n' "[3/7] Installing Curl..."
as_root apt-get install -y curl

printf '%s\n' "[4/7] Upgrading Ubuntu..."
as_root apt-get upgrade -y

printf '%s\n' "[5/7] Removing unused packages..."
as_root apt-get autoremove -y

printf '%s\n' "[6/7] Cleaning APT cache..."
as_root apt-get autoclean

printf '%s\n' "[7/7] Installing/Updating Speedtest CLI..."
if ! command -v speedtest >/dev/null 2>&1; then
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | as_root sh
  else
    printf '%s\n' "CGL+: curl is required to install Speedtest CLI." >&2
    exit 1
  fi
fi
as_root apt-get install -y speedtest

printf '\n%s\n' "CGL+ LabZ | System Information"
if command -v neofetch >/dev/null 2>&1; then
  neofetch
fi

printf '\n%s\n' "CGL+ LabZ | Internet Speed Test"
if command -v speedtest >/dev/null 2>&1; then
  speedtest
fi

printf '\n%s\n' "CGL+ LabZ | Your Ubuntu System Is Now Updated"
