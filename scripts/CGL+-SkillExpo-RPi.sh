#!/bin/sh
set -eu
EXPECTED_KEY="aqs-skille-key1"
ROOT="/opt/cgl-labz"
RAW_BASE="https://raw.githubusercontent.com/cgl-create/cgl/main/packages/skille-secret/rpi"

die() { printf 'CGL+ LabZ: %s\n' "$*" >&2; exit 1; }
check_key() { [ "$1" = "$EXPECTED_KEY" ] || die "invalid SkillExpo Project Key"; }
install_project() {
  key="$1"
  check_key "$key"
  printf '%s\n' "CGL+ LabZ | Installing SkillExpo package..."
  mkdir -p "$ROOT"
  curl -fsSL "$RAW_BASE/app.py" -o "$ROOT/app.py"
  curl -fsSL "$RAW_BASE/requirements.txt" -o "$ROOT/requirements.txt"
  curl -fsSL "$RAW_BASE/cgl-labz.service" -o /tmp/cgl-labz.service
  install -m 0644 /tmp/cgl-labz.service /etc/systemd/system/cgl-labz.service
  rm -f /tmp/cgl-labz.service
  apt-get update
  apt-get install -y python3-gpiozero python3-lgpio
  systemctl daemon-reload
  systemctl enable cgl-labz.service
  systemctl restart cgl-labz.service
  printf '%s\n' "CGL+ LabZ | SkillExpo package installed."
}
case "$1" in
install)
  if [ "$#" -ge 2 ]; then key="$2"; else
    printf '%s\n' "CGL+ LabZ | SkillExpo Project Download"
    printf '%s ' "Please Enter Your SkillExpo Project Key : "
    read -r key
  fi
  install_project "$key"
  ;;
update)
  if [ "$#" -eq 1 ]; then
    printf '%s\n' "CGL+ LabZ | SkillExpo Project Update"
    printf '%s ' "Please Enter Your SkillExpo Project Key : "
    read -r key
  else
    [ "$2" = "-key" ] && [ "$#" -eq 3 ] || die "usage: cgl update -pkg skille-secret [-os rpi] [-key <project-key>]"
    key="$3"
  fi
  install_project "$key"
  printf '%s\n' "CGL+ LabZ | SkillExpo package updated."
  ;;
run)
  [ "$2" = "-key" ] && [ "$3" = "$EXPECTED_KEY" ] || die "usage: cgl run skille-secret -os rpi -key aqs-skille-key1"
  systemctl start cgl-labz.service
  systemctl --no-pager --full status cgl-labz.service
  ;;
*) die "unknown SkillExpo action" ;;
esac
