#!/bin/sh
set -eu
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
  printf '[1/%s] Preparing SkillExpo package ✓\n' "$TOTAL_STEPS"
  printf '[2/%s] Downloading project files ' "$TOTAL_STEPS"
  run_with_spinner "Downloading project files" curl -fsSL "$RAW_BASE/app.py" -o "$ROOT/app.py"
  printf '[3/%s] Downloading package configuration ' "$TOTAL_STEPS"
  run_with_spinner "Downloading package configuration" sh -c 'curl -fsSL "$1/requirements.txt" -o "$2/requirements.txt" && curl -fsSL "$1/cgl-labz.service" -o /tmp/cgl-labz.service' sh "$RAW_BASE" "$ROOT"
  printf '[4/%s] Installing service configuration ' "$TOTAL_STEPS"
  mkdir -p "$ROOT"
  install -m 0644 /tmp/cgl-labz.service /etc/systemd/system/cgl-labz.service
  rm -f /tmp/cgl-labz.service
  printf '\r[4/%s] Installing service configuration ✓\n' "$TOTAL_STEPS"
  printf '[5/%s] Updating package index ' "$TOTAL_STEPS"
  run_with_spinner "Updating package index" apt-get update
  printf '[6/%s] Installing GPIO libraries ' "$TOTAL_STEPS"
  run_with_spinner "Installing GPIO libraries" apt-get install -y python3-gpiozero python3-lgpio
  printf '[7/%s] Enabling and restarting SkillExpo service ' "$TOTAL_STEPS"
  run_with_spinner "Enabling and restarting SkillExpo service" sh -c 'systemctl daemon-reload && systemctl enable cgl-labz.service >/dev/null && systemctl restart cgl-labz.service'
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
