#!/bin/sh
set -eu

# SkillExpo installation manages system-wide files and services. Re-exec through
# sudo automatically so users can run cgl install without typing sudo.
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo "$0" "$@"
  fi
  printf '%s\n' "CGL+ LabZ: root privileges are required and sudo is not installed." >&2
  exit 1
fi

EXPECTED_KEY="aqs-skille-key1"
ROOT="/opt/cgl-labz"
RAW_BASE="https://raw.githubusercontent.com/cgl-create/cgl/main/packages/skille-secret/rpi"

die() { printf 'CGL+ LabZ: %s\n' "$*" >&2; exit 1; }
check_key() { [ "$1" = "$EXPECTED_KEY" ] || die "invalid SkillExpo Project Key"; }
spinner() {
  case "$1" in
    0) printf '%s' '⠋' ;; 1) printf '%s' '⠙' ;; 2) printf '%s' '⠹' ;; 3) printf '%s' '⠸' ;;
    4) printf '%s' '⠼' ;; 5) printf '%s' '⠴' ;; 6) printf '%s' '⠦' ;; 7) printf '%s' '⠧' ;;
    8) printf '%s' '⠇' ;; *) printf '%s' '⠏' ;;
  esac
}
run_with_spinner() {
  label="$1"
  shift
  i=0
  "$@" >"/tmp/cgl-skill-step-$$.log" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s %s' "$label" "$(spinner "$i")"
    i=$(( (i + 1) % 10 ))
    sleep 0.08
  done
  wait "$pid"
  printf '\r%s ✓\n' "$label"
}
install_project() {
  key="$1"
  check_key "$key"
  TOTAL_STEPS=7
  mkdir -p "$ROOT"
  printf '[1/%s] Preparing SkillExpo package ✓\n' "$TOTAL_STEPS"
  run_with_spinner "[2/$TOTAL_STEPS] Downloading project files" curl -fsSL "$RAW_BASE/app.py" -o "$ROOT/app.py"
  run_with_spinner "[3/$TOTAL_STEPS] Downloading package configuration" sh -c 'curl -fsSL "$1/requirements.txt" -o "$2/requirements.txt" && curl -fsSL "$1/cgl-labz.service" -o /tmp/cgl-labz.service' sh "$RAW_BASE" "$ROOT"
  install -m 0644 /tmp/cgl-labz.service /etc/systemd/system/cgl-labz.service
  rm -f /tmp/cgl-labz.service
  printf '[4/%s] Installing service configuration ✓\n' "$TOTAL_STEPS"
  run_with_spinner "[5/$TOTAL_STEPS] Updating package index" apt-get update
  run_with_spinner "[6/$TOTAL_STEPS] Installing GPIO libraries" apt-get install -y python3-gpiozero python3-lgpio
  run_with_spinner "[7/$TOTAL_STEPS] Enabling and restarting SkillExpo service" sh -c 'systemctl daemon-reload && systemctl enable cgl-labz.service >/dev/null && systemctl restart cgl-labz.service'
  rm -f "/tmp/cgl-skill-step-$$.log"
  printf '\nCGL+ LabZ | SkillExpo package successfully updated.\n'
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
