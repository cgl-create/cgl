#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$("$ROOT/cgl" version)" = 'cgl 1.0.6'
"$ROOT/cgl" help >/dev/null
sh -n "$ROOT/cgl"
sh -n "$ROOT/scripts/CGL+-RDP-RPi.sh"
sh -n "$ROOT/install.sh"

# Verify the documented dashed RDP lifecycle spellings are present in the
# command dispatcher. This avoids needing a real /usr/share/cgl install in CI.
for action in '-revoke' '-rst' '-fix'; do
  grep -F "[ \"\$2\" = \"$action\" ]" "$ROOT/cgl" >/dev/null
done

grep -F 'cgl install -revoke rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -rst rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -fix rdp -os rpi' "$ROOT/cgl" >/dev/null

grep -F 'raw.githubusercontent.com/cgl-create/cgl/gh-pages' "$ROOT/cgl" >/dev/null
grep -F 'raw.githubusercontent.com/cgl-create/cgl/gh-pages' "$ROOT/install.sh" >/dev/null

echo 'CGL+ tests passed.'
