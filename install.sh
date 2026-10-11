#!/bin/sh
set -eu
die() { printf 'CGL+ installer: %s\n' "$*" >&2; exit 1; }
OS="$(uname -s)"
# macOS and non-APT Linux: install the CLI and bundled scripts directly.
if [ "$OS" = "Darwin" ] || ! command -v apt-get >/dev/null 2>&1; then
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT HUP INT TERM
  curl -fsSL --proto '=https' --tlsv1.2 "https://github.com/cgl-create/cgl/archive/refs/heads/main.tar.gz" -o "$T/src.tar.gz"
  tar -xzf "$T/src.tar.gz" -C "$T"
  SRC="$T/cgl-main"; [ -f "$SRC/cgl" ] || die "invalid CGL+ source archive"
  if [ "$(id -u)" -eq 0 ]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else die "sudo is required"; fi
  $SUDO mkdir -p /usr/local/share/cgl/scripts /usr/local/bin
  $SUDO cp "$SRC/cgl" /usr/local/share/cgl/cgl
  $SUDO cp "$SRC"/scripts/*.sh /usr/local/share/cgl/scripts/
  $SUDO chmod 0755 /usr/local/share/cgl/cgl /usr/local/share/cgl/scripts/*.sh
  $SUDO ln -sf /usr/local/share/cgl/cgl /usr/local/bin/cgl
  printf '%s\n' "CGL+ CLI installed." "Run: cgl version"
  if [ "$OS" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
    printf '%s\n' "Install Homebrew from https://brew.sh to enable package commands."
  fi
  exit 0
fi
PRIMARY="https://packages.crazygamelabs.co.uk"
FALLBACK="https://raw.githubusercontent.com/cgl-create/cgl/gh-pages"
KEYRING="/usr/share/keyrings/cgl-archive-keyring.gpg"
SOURCES="/etc/apt/sources.list.d/cgl.list"
FPR="60B4D386243F10FBAA2B95C0D2EC0C12FD8D39CC"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v gpg >/dev/null 2>&1 || die "gpg is required"
T="$(mktemp)"; trap 'rm -f "$T"' EXIT HUP INT TERM
URL="$PRIMARY"
if ! curl -fsSL --proto '=https' --tlsv1.2 "$URL/cgl-archive-keyring.gpg" -o "$T"; then
  URL="$FALLBACK"
  curl -fsSL --proto '=https' --tlsv1.2 "$URL/cgl-archive-keyring.gpg" -o "$T" || die "cannot download repository key"
fi
ACTUAL="$(gpg --show-keys --with-colons "$T" 2>/dev/null | awk -F: '$1=="fpr" {print toupper($10); exit}')"
[ "$ACTUAL" = "$FPR" ] || die "repository key fingerprint mismatch"
if [ "$(id -u)" -eq 0 ]; then
  gpg --dearmor < "$T" > "$KEYRING"; chmod 0644 "$KEYRING"
  printf 'deb [signed-by=%s] %s stable main\n' "$KEYRING" "$URL" > "$SOURCES"
else
  command -v sudo >/dev/null 2>&1 || die "sudo is required"
  gpg --dearmor < "$T" | sudo tee "$KEYRING" >/dev/null; sudo chmod 0644 "$KEYRING"
  printf 'deb [signed-by=%s] %s stable main\n' "$KEYRING" "$URL" | sudo tee "$SOURCES" >/dev/null
fi
printf '%s\n' "CGL+ APT repository configured." "Installing CGL+..."
if [ "$(id -u)" -eq 0 ]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y cgl
else
  sudo apt-get update
  sudo apt-get install -y cgl
fi
printf '%s\n' "CGL+ installation complete." "Run: cgl version"
