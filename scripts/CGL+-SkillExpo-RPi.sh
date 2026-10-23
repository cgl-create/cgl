#!/bin/sh
set -eu

# Install or update the CGL+ LabZ local dashboard and standalone Wi-Fi AP.
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then exec sudo "$0" "$@"; fi
  printf '%s\n' "CGL+ LabZ: root privileges are required and sudo is not installed." >&2
  exit 1
fi

EXPECTED_KEY="aqs-skille-key1"
ROOT="/opt/cgl-labz"
RAW_BASE="https://raw.githubusercontent.com/cgl-create/cgl/feature/skille-ap-arduino/packages/skille-secret/rpi"
SSID="CGL+ AP 1"
PASSWORD="CGL+LabZ-AP1"
CONNECTION="CGL-LabZ-AP"
die() { printf 'CGL+ LabZ: %s\n' "$*" >&2; exit 1; }
check_key() { [ "$1" = "$EXPECTED_KEY" ] || die "invalid SkillExpo Project Key"; }

configure_ap() {
  command -v nmcli >/dev/null 2>&1 || die "NetworkManager/nmcli is unavailable. Install NetworkManager, then rerun cgl update."
  systemctl enable --now NetworkManager
  systemctl enable --now avahi-daemon
  install -d -m 0755 /etc/dnsmasq.d
  cat > /etc/dnsmasq.d/cgl-labz-ap.conf <<'EOF'
# DHCP only on the standalone CGL+ LabZ AP. No DNS forwarder or internet gateway.
interface=wlan0
bind-interfaces
dhcp-authoritative
dhcp-range=192.168.4.20,192.168.4.200,255.255.255.0,12h
dhcp-option=3
dhcp-option=6
EOF
  if nmcli -t -f NAME connection show | grep -Fxq "$CONNECTION"; then
    nmcli connection delete "$CONNECTION"
  fi
  nmcli connection add type wifi ifname wlan0 con-name "$CONNECTION" ssid "$SSID"
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
  nmcli connection up "$CONNECTION"
  systemctl restart dnsmasq
  systemctl restart avahi-daemon
  printf '\nCGL+ LabZ access point configured:\n'
  printf '  SSID: %s\n  Password: %s\n' "$SSID" "$PASSWORD"
  printf '  Dashboard: http://cgl-labz.local:5000\n'
  printf '  Fallback:  http://192.168.4.1:5000\n'
}

install_project() {
  check_key "$1"
  mkdir -p "$ROOT"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-serial network-manager dnsmasq avahi-daemon
  curl -fsSL "$RAW_BASE/app.py" -o "$ROOT/app.py"
  curl -fsSL "$RAW_BASE/requirements.txt" -o "$ROOT/requirements.txt"
  curl -fsSL "$RAW_BASE/cgl-labz.service" -o /etc/systemd/system/cgl-labz.service
  chmod 0644 "$ROOT/app.py" "$ROOT/requirements.txt" /etc/systemd/system/cgl-labz.service
  configure_ap
  systemctl daemon-reload
  systemctl enable --now cgl-labz.service
  systemctl restart cgl-labz.service
  printf '\nCGL+ LabZ installed/updated.\n'
}

case "${1:-}" in
install)
  if [ "$#" -ge 2 ]; then key="$2"; else
    printf '%s ' "Please Enter Your SkillExpo Project Key: "
    read -r key
  fi
  install_project "$key"
  ;;
update)
  if [ "$#" -eq 1 ]; then
    printf '%s ' "Please Enter Your SkillExpo Project Key: "
    read -r key
  else
    [ "$2" = "-key" ] && [ "$#" -eq 3 ] || die "usage: cgl update -pkg skille-secret [-os rpi] [-key <project-key>]"
    key="$3"
  fi
  install_project "$key"
  ;;
run)
  [ "${2:-}" = "-key" ] && [ "${3:-}" = "$EXPECTED_KEY" ] || die "usage: cgl run skille-secret -os rpi -key aqs-skille-key1"
  systemctl start cgl-labz.service
  systemctl --no-pager --full status cgl-labz.service
  ;;
*) die "unknown SkillExpo action" ;;
esac
