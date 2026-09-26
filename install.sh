#!/bin/sh
set -eu

# Universal bootstrap installer for Linux. This installs the CGL+ CLI and
# bundled scripts directly, so CGL can be bootstrapped before an APT package
# repository is configured.
INSTALL_DIR="${CGL_INSTALL_DIR:-/usr/local/bin}"
SHARE_DIR="${CGL_SHARE_DIR:-/usr/local/share/cgl}"
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET="$INSTALL_DIR/cgl"

[ "$(uname -s)" = "Linux" ] || { echo "CGL+: Linux is required." >&2; exit 1; }

install_files() {
  mkdir -p "$INSTALL_DIR" "$SHARE_DIR/scripts"
  cp "$ROOT/cgl" "$TARGET"
  cp "$ROOT/scripts/CGL+-RPiOS-Update.sh" "$SHARE_DIR/scripts/CGL+-RPiOS-Update.sh"
  chmod 0755 "$TARGET" "$SHARE_DIR/scripts/CGL+-RPiOS-Update.sh"
}

if [ "$(id -u)" -eq 0 ]; then
  install_files
else
  command -v sudo >/dev/null 2>&1 || { echo "CGL+: sudo is required when not running as root." >&2; exit 1; }
  sudo sh -c '
    set -eu
    mkdir -p "$1" "$2/scripts"
    cp "$3/cgl" "$1/cgl"
    cp "$3/scripts/CGL+-RPiOS-Update.sh" "$2/scripts/CGL+-RPiOS-Update.sh"
    chmod 0755 "$1/cgl" "$2/scripts/CGL+-RPiOS-Update.sh"
  ' sh "$INSTALL_DIR" "$SHARE_DIR" "$ROOT"
fi

printf 'CGL+ installed to %s\n' "$TARGET"
printf 'Run: cgl doctor\n'
