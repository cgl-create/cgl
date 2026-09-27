#!/bin/sh
set -eu
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
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
  as_root rm -f /etc/wayvnc/cgl-rdp-key.pem /etc/wayvnc/cgl-rdp-cert.pem /etc/wayvnc/config.cgl-backup
  if command -v apt-get >/dev/null 2>&1; then
    as_root apt-get remove -y novnc websockify 2>/dev/null || true
    as_root apt-mark manual wayvnc 2>/dev/null || true
  fi
}

case "$ACTION" in
  install) exec "$WEB" "Raspberry Pi OS" ;;
  revoke)
    printf '%s\n' "CGL+ LabZ | Revoking RDP..."
    remove_rdp
    printf '%s\n' "CGL+: CGL+ RDP removed. Existing WayVNC configuration and Linux passwords were left untouched."
    printf '%s\n' "CGL+: No CGL+ password is stored on disk."
    ;;
  rst)
    printf '%s\n' "CGL+ LabZ | Resetting RDP..."
    remove_rdp
    exec "$WEB" "Raspberry Pi OS"
    ;;
  fix)
    printf '%s\n' "CGL+ LabZ | Fixing RDP while preserving configuration..."
    remove_rdp
    exec "$WEB" "Raspberry Pi OS"
    ;;
  *) printf '%s\n' "CGL+: unknown RDP action: $ACTION" >&2; exit 2 ;;
esac
