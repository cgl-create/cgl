#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="$ROOT/dist"
VERSION="$(sed -n 's/^Version: //p' "$ROOT/package/DEBIAN/control" | head -n1)"
mkdir -p "$OUT" "$ROOT/package/usr/share/cgl/scripts"
cp "$ROOT/cgl" "$ROOT/package/usr/share/cgl/cgl"
cp "$ROOT/scripts/CGL+-RPiOS-Update.sh" "$ROOT/package/usr/share/cgl/scripts/CGL+-RPiOS-Update.sh"
chmod 0755 "$ROOT/package/usr/share/cgl/cgl" "$ROOT/package/usr/share/cgl/scripts/CGL+-RPiOS-Update.sh" "$ROOT/package/usr/bin/cgl" "$ROOT/package/DEBIAN/postinst"
dpkg-deb --build --root-owner-group "$ROOT/package" "$OUT/cgl_${VERSION}_all.deb"
echo "Built $OUT/cgl_${VERSION}_all.deb"
