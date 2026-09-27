#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$("$ROOT/cgl" version)" = 'cgl 1.0.5'
"$ROOT/cgl" help >/dev/null
# Verify all documented RDP lifecycle spellings are accepted by the CLI parser.
# The installed script is not required here; the test only reaches the action
# handler and confirms it does not reject the dashed action as unknown.
for action in -revoke -rst -fix; do
  output="$($ROOT/cgl install "$action" rdp -os rpi 2>&1 || true)"
  case "$output" in
    *"unknown RDP action"*)
      echo "RDP action parser rejected $action" >&2
      exit 1
      ;;
  esac
done
echo 'CGL+ tests passed.'
