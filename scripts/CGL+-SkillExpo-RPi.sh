#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then exec sudo "$0" "$@"; fi
  echo "CGL+ LabZ: root privileges are required." >&2
  exit 1
fi

EXPECTED_KEY="aqs-skille-key1"
ROOT="/opt/cgl-labz"
RAW_BASE="https://raw.githubusercontent.com/cgl-create/cgl/main/packages/skille-secret/rpi"
CONNECTION="CGL-LabZ-AP"
SSID="CGL+ AP 1"
PASSWORD="CGL+LabZ-AP1"
die() { printf 'CGL+ LabZ: %s\n' "$*" >&2; exit 1; }

configure_ap() {
  command -v nmcli >/dev/null 2>&1 || die "NetworkManager/nmcli is unavailable."
  systemctl enable --now NetworkManager
  systemctl enable --now avahi-daemon
  rfkill unblock wifi 2>/dev/null || true
  nmcli radio wifi on
  install -d -m 0755 /etc/dnsmasq.d
  cat > /etc/dnsmasq.d/cgl-labz-ap.conf <<'EOF'
interface=wlan0
bind-interfaces
dhcp-authoritative
dhcp-range=192.168.4.20,192.168.4.200,255.255.255.0,12h
dhcp-option=3
dhcp-option=6
EOF
  if nmcli -t -f NAME connection show | grep -Fxq "$CONNECTION"; then
    nmcli connection modify "$CONNECTION" connection.interface-name wlan0 connection.autoconnect yes connection.autoconnect-priority 100
  else
    nmcli connection add type wifi ifname wlan0 con-name "$CONNECTION" ssid "$SSID"
  fi
  nmcli connection modify "$CONNECTION" \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    802-11-wireless.channel 6 \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$PASSWORD" \
    ipv4.method manual \
    ipv4.addresses 192.168.4.1/24 \
    ipv4.never-default yes \
    ipv6.method disabled \
    connection.autoconnect yes \
    connection.autoconnect-priority 100
  hostnamectl set-hostname cgl-labz
  # AP activation is handled by the persistent systemd supervisor below.
  systemctl enable --now dnsmasq
  systemctl restart avahi-daemon
}

install_project() {
  [ "$1" = "$EXPECTED_KEY" ] || die "invalid SkillExpo Project Key"
  mkdir -p "$ROOT"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-serial network-manager dnsmasq avahi-daemon rfkill
  curl -fsSL "$RAW_BASE/app.py" -o "$ROOT/app.py"
  curl -fsSL "$RAW_BASE/requirements.txt" -o "$ROOT/requirements.txt"
  curl -fsSL "$RAW_BASE/cgl-labz.service" -o /etc/systemd/system/cgl-labz.service
  curl -fsSL "$RAW_BASE/cgl-labz-ap.service" -o /etc/systemd/system/cgl-labz-ap.service
  chmod 0644 "$ROOT/app.py" "$ROOT/requirements.txt" /etc/systemd/system/cgl-labz.service /etc/systemd/system/cgl-labz-ap.service
  configure_ap
  systemctl daemon-reload
  systemctl enable --now cgl-labz-ap.service
  systemctl enable --now cgl-labz.service
  systemctl restart cgl-labz.service
  echo "CGL+ LabZ installed/updated."
}

case "${1:-}" in
  install|update)
    if [ "$#" -ge 2 ]; then key="$2"; else
      printf '%s ' "Please Enter Your SkillExpo Project Key: "
      read -r key
    fi
    install_project "$key"
    ;;
  run)
    [ "${2:-}" = "-key" ] && [ "${3:-}" = "$EXPECTED_KEY" ] || die "invalid run arguments"
    systemctl start cgl-labz.service
    systemctl --no-pager --full status cgl-labz.service
    ;;
  *) die "unknown SkillExpo action" ;;
esac
