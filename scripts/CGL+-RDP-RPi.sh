#!/bin/sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Accept both internal action names and the public CLI spellings.
ACTION="${1:-install}"
ACTION="${ACTION#-}"
WEB="$SCRIPT_DIR/CGL+-RDP-Web.sh"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else printf '%s\n' "CGL+: root privileges are required." >&2; exit 1
  fi
}

remove_rdp() {
  as_root systemctl disable --now cgl-rdp-web.service 2>/dev/null || true
  as_root rm -f /etc/systemd/system/cgl-rdp-web.service
  as_root systemctl daemon-reload
  as_root rm -rf /usr/share/cgl/rdp-web
  as_root rm -f /etc/wayvnc/cgl-rdp-key.pem /etc/wayvnc/cgl-rdp-cert.pem
  if command -v apt-get >/dev/null 2>&1; then
    as_root apt-get remove -y novnc websockify 2>/dev/null || true
  fi
}

case "$ACTION" in
  install) exec "$WEB" "Raspberry Pi OS" ;;
  revoke)
    printf '%s\n' "CGL+ LabZ | Revoking RDP..."
    remove_rdp
    as_root rm -f /etc/wayvnc/config.cgl-backup
    printf '%s\n' "CGL+: RDP removed. Existing WayVNC configuration was left untouched."
    ;;
  rst)
    printf '%s\n' "CGL+ LabZ | Resetting RDP..."
    remove_rdp
    as_root rm -f /etc/wayvnc/config.cgl-backup
    exec "$WEB" "Raspberry Pi OS"
    ;;
  fix)
    printf '%s\n' "CGL+ LabZ | Fixing RDP while preserving configuration..."
    SAVED="$(mktemp)"
    trap 'rm -f "$SAVED"' EXIT
    if [ -f /etc/wayvnc/config ]; then as_root cp /etc/wayvnc/config "$SAVED"; fi
    remove_rdp
    "$WEB" "Raspberry Pi OS"
    if [ -s "$SAVED" ]; then
      as_root cp "$SAVED" /etc/wayvnc/config
      as_root rm -f /etc/wayvnc/config.cgl-backup
    fi
    printf '%s\n' "CGL+: Existing WayVNC configuration preserved."
    printf '%s\n' "CGL+: Linux/PAM passwords are not stored in plaintext by CGL+."
    ;;
  *) printf '%s\n' "CGL+: unknown RDP action: $ACTION" >&2; exit 2 ;;
esac
