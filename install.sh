#!/bin/sh
set -eu

REPO_URL="https://packages.crazygamelabs.co.uk"
KEY_URL="$REPO_URL/cgl-archive-keyring.gpg"
KEYRING="/usr/share/keyrings/cgl-archive-keyring.gpg"
SOURCES="/etc/apt/sources.list.d/cgl.list"
EXPECTED_FINGERPRINT="60B4D386243F10FBAA2B95C0D2EC0C12FD8D39CC"

die() {
  printf 'CGL+ installer: %s\n' "$*" >&2
  exit 1
}

command -v apt-get >/dev/null 2>&1 || die "apt-get is required"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v gpg >/dev/null 2>&1 || die "gpg is required"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

printf 'Downloading CGL+ repository key...\n'
curl -fsSL --proto '=https' --tlsv1.2 "$KEY_URL" -o "$TMP"

ACTUAL_FINGERPRINT="$(gpg --show-keys --with-colons "$TMP" 2>/dev/null |
  awk -F: '$1=="fpr" {print toupper($10); exit}')"

[ "$ACTUAL_FINGERPRINT" = "$EXPECTED_FINGERPRINT" ] ||
  die "repository key fingerprint mismatch"

if [ "$(id -u)" -eq 0 ]; then
  gpg --dearmor < "$TMP" > "$KEYRING"
  chmod 0644 "$KEYRING"
  printf '%s\n' "deb [signed-by=$KEYRING] $REPO_URL stable main" > "$SOURCES"
else
  command -v sudo >/dev/null 2>&1 || die "sudo is required when not running as root"
  gpg --dearmor < "$TMP" | sudo tee "$KEYRING" >/dev/null
  sudo chmod 0644 "$KEYRING"
  printf '%s\n' "deb [signed-by=$KEYRING] $REPO_URL stable main" | sudo tee "$SOURCES" >/dev/null
fi

printf 'CGL+ APT repository configured successfully.\n'
printf 'No package was installed.\n'
printf 'Run: sudo apt update && sudo apt install cgl\n'
