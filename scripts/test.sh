#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$("$ROOT/cgl" version)" = 'cgl 1.0.5'
"$ROOT/cgl" help >/dev/null
sh -n "$ROOT/cgl"

# Verify the documented dashed RDP lifecycle spellings are present in the
# command dispatcher. This avoids needing a real /usr/share/cgl install in CI.
for action in '-revoke' '-rst' '-fix'; do
  grep -F "[ \"\$2\" = \"$action\" ]" "$ROOT/cgl" >/dev/null
done

grep -F 'cgl install -revoke rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -rst rdp -os rpi' "$ROOT/cgl" >/dev/null
grep -F 'cgl install -fix rdp -os rpi' "$ROOT/cgl" >/dev/null

echo 'CGL+ tests passed.'
