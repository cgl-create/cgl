#!/bin/sh
set -eu

APP_DIR="${HOME:?HOME is not set}/.local/share/cgl/qmle"
BIN_DIR="${HOME:?HOME is not set}/.local/bin"
LAUNCHER="$BIN_DIR/qmle"
RAW_BASE="https://raw.githubusercontent.com/cgl-create/cgl/main/apps/qmle"

die() { printf 'CGL+ QMLE: %s\n' "$*" >&2; exit 1; }

install_or_update() {
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v python3 >/dev/null 2>&1 || die "Python 3 is required"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT HUP INT TERM
  curl -fsSL --proto '=https' --tlsv1.2 "$RAW_BASE/qmle.py" -o "$tmp/qmle.py" || die "could not download QMLE source"
  curl -fsSL --proto '=https' --tlsv1.2 "$RAW_BASE/requirements.txt" -o "$tmp/requirements.txt" || die "could not download QMLE requirements"
  grep -q 'pygame-ce' "$tmp/requirements.txt" || die "invalid requirements file"
  grep -q 'cryptography' "$tmp/requirements.txt" || die "invalid requirements file"

  mkdir -p "$APP_DIR" "$BIN_DIR"
  install -m 0644 "$tmp/qmle.py" "$APP_DIR/qmle.py"
  install -m 0644 "$tmp/requirements.txt" "$APP_DIR/requirements.txt"
  if [ ! -x "$APP_DIR/.venv/bin/python" ]; then
    python3 -m venv "$APP_DIR/.venv" || die "Python venv support is required"
  fi
  "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
  "$APP_DIR/.venv/bin/python" -m pip install --only-binary=:all: -r "$APP_DIR/requirements.txt" ||
    die "no compatible binary dependency wheels were found for this Python version and architecture"

  cat > "$LAUNCHER" <<'EOF'
#!/bin/sh
set -eu
APP_DIR="${HOME:?HOME is not set}/.local/share/cgl/qmle"
exec "$APP_DIR/.venv/bin/python" "$APP_DIR/qmle.py" "$@"
EOF
  chmod 0755 "$LAUNCHER"
  printf '%s\n' "QMLE by CGL+ installed/updated." "Launch with: qmle"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) printf 'Add %s to PATH to run qmle from any terminal.\n' "$BIN_DIR" ;; esac
}

revoke() {
  rm -f "$LAUNCHER"
  rm -rf "$APP_DIR"
  printf '%s\n' "QMLE by CGL+ revoked." "Encryption keys in ~/.config/qmle/ were preserved."
}

case "${1:-install}" in
  install|update) install_or_update ;;
  revoke) revoke ;;
  *) die "usage: cgl install qmle | cgl install -update qmle | cgl install -revoke qmle" ;;
esac
