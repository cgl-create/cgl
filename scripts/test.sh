#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$("$ROOT/cgl" version)" = 'cgl 1.0.12'
"$ROOT/cgl" help >/dev/null
sh -n "$ROOT/cgl"
sh -n "$ROOT/scripts/CGL+-RDP-RPi.sh"
sh -n "$ROOT/scripts/CGL+-RDP-Web.sh"
sh -n "$ROOT/install.sh"

for action in '-revoke' '-rst' '-fix'; do
  grep -F "[ \"\$2\" = \"$action\" ]" "$ROOT/cgl" >/dev/null
done

grep -F 'cgl install -revoke rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -rst rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -fix rdp -os rpi' "$ROOT/cgl" >/dev/null

grep -F 'raw.githubusercontent.com/cgl-create/cgl/gh-pages' "$ROOT/cgl" >/dev/null
grep -F 'raw.githubusercontent.com/cgl-create/cgl/gh-pages' "$ROOT/install.sh" >/dev/null

# RDP must preserve the existing WayVNC configuration and session.
! grep -F 'pkill -x wayvnc' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
! grep -F 'cat > /etc/wayvnc/config' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
! grep -F 'cgl-rdp-key.pem' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'CODESPACES' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'websockify' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'Xvfb "$DISPLAY_NUM"' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'metacity --replace' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'gnome-panel' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null
grep -F 'x11vnc' "$ROOT/scripts/CGL+-RDP-Web.sh" >/dev/null

echo 'CGL+ tests passed.'
