#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$("$ROOT/cgl" version)" = 'cgl 1.0.2'
"$ROOT/cgl" help >/dev/null
echo 'CGL+ tests passed.'
