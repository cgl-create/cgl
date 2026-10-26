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
APT_CGL_SOURCE="/etc/apt/sources.list.d/cgl.list"
APT_CGL_PRIMARY="https://packages.crazygamelabs.co.uk"
APT_CGL_FALLBACK="https://raw.githubusercontent.com/cgl-create/cgl/gh-pages"
die() { printf 'CGL+ LabZ: %s\n' "$*" >&2; exit 1; }

apt_update_safe() {
  # If the CGL+ package mirror is unavailable, switch its source to the
  # maintained GitHub Pages mirror before apt-get update.
  if [ -f "$APT_CGL_SOURCE" ] &&
     grep -q 'packages.crazygamelabs.co.uk' "$APT_CGL_SOURCE" 2>/dev/null; then
    if command -v curl >/dev/null 2>&1; then
      if ! curl -fsSL --max-time 6 --proto '=https' --tlsv1.2 \
        "$APT_CGL_PRIMARY/dists/stable/Release" >/dev/null 2>&1; then
        if [ -f /usr/share/keyrings/cgl-archive-keyring.gpg ]; then
          printf '%s\n' "CGL+ | Primary package mirror unavailable; switching to fallback."
          printf '%s\n' "deb [signed-by=/usr/share/keyrings/cgl-archive-keyring.gpg] $APT_CGL_FALLBACK stable main" > "$APT_CGL_SOURCE"
        else
          printf '%s\n' "CGL+ | Primary package mirror unavailable; keeping existing APT sources." >&2
        fi
      fi
    fi
  fi
  apt-get update
}

fetch_file() {
  url="$1"
  destination="$2"
  temporary="${destination}.tmp"
  rm -f "$temporary"
  if command -v curl >/dev/null 2>&1; then
    curl -fLsS --retry 3 --connect-timeout 10 "$url" -o "$temporary"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --tries=3 --timeout=10 -O "$temporary" "$url"
  else
    die "curl or wget is required to download the CGL+ LabZ files."
  fi
  [ -s "$temporary" ] || die "download was empty: $url"
  mv "$temporary" "$destination"
}

configure_ap() {
  command -v nmcli >/dev/null 2>&1 || die "NetworkManager/nmcli is unavailable."
  systemctl enable --now NetworkManager
  systemctl enable --now avahi-daemon
  rfkill unblock wifi 2>/dev/null || true
  nmcli radio wifi on
  install -d -m 0755 /etc/dnsmasq.d
  cat > /etc/dnsmasq.d/cgl-labz-ap.conf <<'EOF'
interface=wlan0
bind-dynamic
port=0
dhcp-authoritative
dhcp-range=192.168.4.20,192.168.4.200,255.255.255.0,12h
dhcp-option=3
dhcp-option=6
EOF
  if nmcli -t -f NAME connection show | grep -Fxq "$CONNECTION"; then
    nmcli connection modify "$CONNECTION" connection.interface-name wlan0
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
  # Activation and recovery are managed by the persistent systemd supervisor.
  systemctl enable --now dnsmasq
  systemctl restart avahi-daemon
}

install_project() {
  [ "$1" = "$EXPECTED_KEY" ] || die "invalid SkillExpo Project Key"
  mkdir -p "$ROOT"
  apt_update_safe
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl python3 python3-serial network-manager dnsmasq avahi-daemon rfkill iproute2
  fetch_file "$RAW_BASE/app.py" "$ROOT/app.py"
  fetch_file "$RAW_BASE/requirements.txt" "$ROOT/requirements.txt"
  fetch_file "$RAW_BASE/cgl-labz.service" /etc/systemd/system/cgl-labz.service
  fetch_file "$RAW_BASE/cgl-labz-ap.service" /etc/systemd/system/cgl-labz-ap.service
  chmod 0644 "$ROOT/app.py" "$ROOT/requirements.txt" /etc/systemd/system/cgl-labz.service /etc/systemd/system/cgl-labz-ap.service
  /usr/bin/python3 -m py_compile "$ROOT/app.py" || die "dashboard Python syntax check failed."
  configure_ap
  systemctl daemon-reload
  systemctl enable --now cgl-labz-ap.service
  systemctl enable --now cgl-labz.service
  systemctl restart cgl-labz.service
  echo "CGL+ LabZ installed/updated."
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
    [ "${2:-}" = "-key" ] && [ "${3:-}" = "$EXPECTED_KEY" ] || die "invalid run arguments"
    systemctl start cgl-labz.service
    systemctl --no-pager --full status cgl-labz.service
    ;;
  *) die "unknown SkillExpo action" ;;
esac
