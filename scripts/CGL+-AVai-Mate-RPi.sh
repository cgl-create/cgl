#!/bin/sh
set -eu
NAME="CGL+ AVai Mate Pi"
ROOT="/opt/cgl-avai-mate"
ETC="/etc/cgl-avai-mate"
RAW="https://raw.githubusercontent.com/cgl-create/CGL-Labratories-AVai-Mate/main/pi"
SERVICE="/etc/systemd/system/avai-mate-pi.service"
die() { printf '%s: %s\n' "$NAME" "$*" >&2; exit 1; }
say() { printf '%s\n' "$NAME | $*"; }
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  exec sudo sh "$0" "$@"
fi
[ -r /etc/os-release ] || die "Cannot identify the operating system."
. /etc/os-release
case "\${ID:-}" in
  raspbian|debian) ;;
  *) case "\${ID_LIKE:-}" in *debian*) ;; *) die "This package currently targets Raspberry Pi OS / Debian."; ;; esac ;;
esac
command -v apt-get >/dev/null 2>&1 || die "APT is required on Raspberry Pi OS."
command -v curl >/dev/null 2>&1 || die "curl is required."
install_agent() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3 ca-certificates curl avahi-daemon bluez
  if apt-cache show python3-gpiozero >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3-gpiozero
  fi
  if apt-cache show python3-bluez >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3-bluez
  fi
  install -d -m 0750 "$ROOT" "$ETC" /var/lib/cgl-avai-mate
  curl -fLsS --retry 3 --proto '=https' --tlsv1.2 "$RAW/agent.py" -o "$ROOT/agent.py.tmp"
  test -s "$ROOT/agent.py.tmp" || die "Agent download was empty."
  mv "$ROOT/agent.py.tmp" "$ROOT/agent.py"
  curl -fLsS --retry 3 --proto '=https' --tlsv1.2 "$RAW/avai-mate-pi.service" -o "$SERVICE.tmp"
  test -s "$SERVICE.tmp" || die "systemd unit download was empty."
  mv "$SERVICE.tmp" "$SERVICE"
  chmod 0755 "$ROOT/agent.py"
  chmod 0644 "$SERVICE"
  if [ ! -s "$ETC/admin.pin" ]; then
    /usr/bin/python3 -c 'import secrets; print(secrets.token_hex(4).upper())' > "$ETC/admin.pin"
    chmod 0600 "$ETC/admin.pin"
  fi
  if [ ! -s "$ETC/config.json" ]; then
    cat > "$ETC/config.json" <<'EOF'
{
  "driver": "mock",
  "pins": {
    "left_forward": null,
    "left_backward": null,
    "right_forward": null,
    "right_backward": null
  },
  "motor_enabled": false,
  "local_token_hash": "",
  "cloud_endpoint": "https://cgl-avai-mate-memory-api.nikshith.workers.dev"
}
EOF
    chmod 0600 "$ETC/config.json"
  fi
  /usr/bin/python3 -m py_compile "$ROOT/agent.py" || die "Pi agent Python syntax validation failed."
  systemctl enable --now avahi-daemon
  if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    systemctl enable --now bluetooth.service 2>/dev/null || true
  fi
  systemctl daemon-reload
  systemctl enable --now avai-mate-pi.service
  systemctl restart avai-mate-pi.service
  PIN="$(cat "$ETC/admin.pin")"
  HOST="$(hostname)"
  printf '\n'
  say "Pi body agent installed and running."
  say "Local dashboard: http://\${HOST}.local:8765"
  say "Fallback: http://<Pi-LAN-IP>:8765"
  say "Local dashboard PIN: $PIN"
  say "Default driver: MOCK. No GPIO motor output is enabled."
  say "Use the dashboard to link Cloudflare, create a phone token, and configure your verified motor driver."
}
case "\${1:-install}" in
  install|update) install_agent ;;
  status) systemctl --no-pager --full status avai-mate-pi.service ;;
  stop) systemctl stop avai-mate-pi.service ;;
  restart) systemctl restart avai-mate-pi.service ;;
  revoke|remove)
    systemctl disable --now avai-mate-pi.service 2>/dev/null || true
    rm -f "$SERVICE"
    systemctl daemon-reload
    say "Service removed. Configuration and device tokens were retained at $ETC."
    ;;
  *) die "unknown action. Supported internal actions: install, update, status, stop, restart, revoke." ;;
esac
