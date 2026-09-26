#!/bin/sh
set -eu

# Universal bootstrap installer for Linux. This installs the CGL+ CLI
# directly, so CGL can be bootstrapped even when no CGL repository exists yet.
INSTALL_DIR="${CGL_INSTALL_DIR:-/usr/local/bin}"
BASE_URL="${CGL_BOOTSTRAP_URL:-https://raw.githubusercontent.com/cgl-create/cgl/main}"
TARGET="$INSTALL_DIR/cgl"

[ "$(uname -s)" = "Linux" ] || { echo "CGL+: Linux is required." >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$INSTALL_DIR"
  cp "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/cgl" "$TARGET"
else
  command -v sudo >/dev/null 2>&1 || { echo "CGL+: sudo is required when not running as root." >&2; exit 1; }
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/cgl" "$TARGET"
fi

chmod 0755 "$TARGET" 2>/dev/null || sudo chmod 0755 "$TARGET"
printf 'CGL+ installed to %s\n' "$TARGET"
printf 'Run: cgl doctor\n'
