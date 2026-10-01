#!/bin/sh
set -eu

TARGET_LABEL="${1:-Linux}"
NOVNC_VERSION="1.7.0"
NOVNC_URL="https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz"
CODESPACE_MODE=0
if [ -n "${CODESPACES:-}" ] || [ -n "${CODESPACE_NAME:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ]; then
  CODESPACE_MODE=1
fi

clear
printf '%s\n' "CGL+ LabZ | Current Desktop Browser RDP"
printf '%s\n\n' "Configuring CGL+ RDP for $TARGET_LABEL..."

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else printf '%s\n' "CGL+: root privileges are required." >&2; exit 1
  fi
}

install_novnc() {
  rdp_dir="$1"
  novnc_dir="$rdp_dir/novnc"
  version_file="$novnc_dir/.cgl-novnc-version"

  if [ -f "$version_file" ] && [ "$(cat "$version_file" 2>/dev/null || true)" = "$NOVNC_VERSION" ] && [ -f "$novnc_dir/core/rfb.js" ]; then
    printf '%s\n' "CGL+: noVNC $NOVNC_VERSION is already installed."
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT INT TERM
  printf '%s\n' "CGL+: Installing noVNC $NOVNC_VERSION..."
  curl -fsSL --proto '=https' --tlsv1.2 "$NOVNC_URL" -o "$tmp_dir/novnc.tar.gz"
  tar -xzf "$tmp_dir/novnc.tar.gz" -C "$tmp_dir"
  [ -f "$tmp_dir/noVNC-$NOVNC_VERSION/core/rfb.js" ] || {
    printf '%s\n' "CGL+: Downloaded noVNC package is invalid." >&2
    exit 1
  }

  as_root rm -rf "$novnc_dir"
  as_root mv "$tmp_dir/noVNC-$NOVNC_VERSION" "$novnc_dir"
  printf '%s\n' "$NOVNC_VERSION" | as_root tee "$version_file" >/dev/null
  as_root chmod 0755 "$novnc_dir"
  rm -rf "$tmp_dir"
  trap - EXIT INT TERM
}

if [ "$CODESPACE_MODE" -eq 1 ]; then
  printf '%s\n' "[Codespace] Development/test environment detected."
  printf '%s\n' "CGL+: Starting a separate GNOME desktop for Codespace RDP."
  printf '%s\n' "CGL+: The Raspberry Pi Wayland/WayVNC session will not be touched."

  RDP_DIR="/usr/share/cgl/rdp-web"
  RDP_STATE="/tmp/cgl-rdp-$USER"
  DISPLAY_NUM=":99"
  VNC_PORT="5901"
  WEB_PORT="1350"
  mkdir -p "$RDP_STATE/runtime"
  chmod 700 "$RDP_STATE" "$RDP_STATE/runtime"

  printf '%s\n' "[1/5] Checking desktop and RDP dependencies..."
  if ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1 || ! command -v websockify >/dev/null 2>&1 || ! command -v Xvfb >/dev/null 2>&1 || ! command -v x11vnc >/dev/null 2>&1 || ! command -v gnome-session >/dev/null 2>&1 || ! command -v gnome-flashback >/dev/null 2>&1; then
    printf '%s\n' "CGL+: Installing Codespace desktop/RDP dependencies..."
    as_root apt-get update
    as_root apt-get install -y curl openssl websockify xvfb x11vnc dbus-x11 gnome-session gnome-shell gnome-session-flashback
  fi

  for tool in Xvfb x11vnc dbus-run-session gnome-session websockify; do
    command -v "$tool" >/dev/null 2>&1 || { printf '%s\n' "CGL+: Required tool missing: $tool" >&2; exit 1; }
  done
  printf '%s\n' "[2/5] Preparing CGL+ browser gateway..."
  as_root mkdir -p "$RDP_DIR"
  install_novnc "$RDP_DIR"
  as_root chmod 0755 "$RDP_DIR"
  as_root sh -c 'cat > /usr/share/cgl/rdp-web/index.html' <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ RDP — Codespace</title>
<style>
:root{--yellow:#f2c94c;--bg:#070707;--text:#f5f5f5;--muted:#9b9b9b}
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{overflow:hidden}#login{height:100%;display:grid;place-items:center;padding:24px;background:radial-gradient(circle at 50% 35%,#24200e 0,#0b0b0b 38%,#050505 100%)}
.card{width:min(420px,100%);background:#111;border:1px solid #292929;border-radius:24px;padding:32px;box-shadow:0 24px 80px #000}
.logo{font-weight:900;font-size:42px;letter-spacing:-2px;color:var(--yellow)}.logo span{color:#fff}
h1{font-size:25px;margin:18px 0 7px}.sub{color:var(--muted);margin:0 0 25px;line-height:1.5}
button{width:100%;border:0;border-radius:12px;padding:13px 17px;font-weight:800;cursor:pointer;background:var(--yellow);color:#111;font-size:15px}
.note{margin-top:20px;color:#777;font-size:11px;line-height:1.45}#desktop{display:none;width:100%;height:100%;position:relative;background:#202020}
#screen{position:absolute;inset:48px 0 0;overflow:hidden}#bar{height:48px;position:absolute;z-index:10;left:0;right:0;top:0;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#0b0b0bf2;border-bottom:1px solid #292929}
#brand{font-weight:900;color:var(--yellow);margin-right:auto}#status{font-size:12px;color:#aaa}.tool{width:auto;background:#1c1c1c;color:#eee;border:1px solid #303030}
#screen>div{width:100%!important;height:100%!important}
</style>
</head>
<body>
<section id="login"><div class="card"><div class="logo">CGL<span>+</span></div><h1>Codespace RDP</h1><p class="sub">Connect to the isolated GNOME desktop running inside this Codespace.</p><button id="connect">Connect</button><div class="note">This desktop is separate from the Raspberry Pi. Access is protected by the private Codespace port.</div></div></section>
<section id="desktop"><div id="bar"><div id="brand">CGL+ RDP</div><div id="status">Connecting…</div><button class="tool" id="cad">Ctrl+Alt+Del</button><button class="tool" id="disconnect">Disconnect</button></div><div id="screen"></div></section>
<script type="module">
import RFB from "/novnc/core/rfb.js";
let rfb=null;
const login=document.getElementById("login"),desktop=document.getElementById("desktop"),screen=document.getElementById("screen"),status=document.getElementById("status");
document.getElementById("connect").addEventListener("click",()=>{
  login.style.display="none";desktop.style.display="block";
  const scheme=location.protocol==="https:"?"wss":"ws";
  rfb=new RFB(screen,scheme+"://"+location.host+"/websockify",{shared:true});
  rfb.scaleViewport=true;rfb.clipViewport=true;rfb.resizeSession=false;
  rfb.addEventListener("connect",()=>{status.textContent="Connected";rfb.focus();});
  rfb.addEventListener("disconnect",()=>{desktop.style.display="none";login.style.display="grid";status.textContent="Disconnected";rfb=null;});
});
document.getElementById("cad").addEventListener("click",()=>{if(rfb)rfb.sendCtrlAltDel();});
document.getElementById("disconnect").addEventListener("click",()=>{if(rfb)rfb.disconnect();});
</script>
</body>
</html>
EOF
  as_root chmod 0644 "$RDP_DIR/index.html"

  printf '%s\n' "[3/5] Starting an isolated X display and GNOME session..."
  for f in "$RDP_STATE/xvfb.pid" "$RDP_STATE/gnome.pid" "$RDP_STATE/x11vnc.pid" "$RDP_STATE/websockify.pid"; do
    if [ -f "$f" ]; then
      pid="$(cat "$f" 2>/dev/null || true)"
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; fi
    fi
    rm -f "$f"
  done

  Xvfb "$DISPLAY_NUM" -screen 0 1280x800x24 -ac +extension GLX +render -noreset >"$RDP_STATE/xvfb.log" 2>&1 &
  echo $! >"$RDP_STATE/xvfb.pid"
  sleep 2
  kill -0 "$(cat "$RDP_STATE/xvfb.pid")" 2>/dev/null || { printf '%s\n' "CGL+: Xvfb failed. See $RDP_STATE/xvfb.log." >&2; exit 1; }

  # Do not launch gnome-session here: even its Flashback session tries to
  # contact the systemd system bus, which Codespaces do not provide. Start the
  # GNOME Flashback components directly inside one private D-Bus session instead.
  DISPLAY="$DISPLAY_NUM" XDG_RUNTIME_DIR="$RDP_STATE/runtime" GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 dbus-run-session -- sh -c '
    gnome-settings-daemon >/tmp/cgl-rdp-settings.log 2>&1 &
    metacity --replace >/tmp/cgl-rdp-metacity.log 2>&1 &
    gnome-panel >/tmp/cgl-rdp-panel.log 2>&1 &
    nautilus --no-default-window >/tmp/cgl-rdp-nautilus.log 2>&1 &
    wait
  ' >"$RDP_STATE/gnome.log" 2>&1 &
  echo $! >"$RDP_STATE/gnome.pid"
  sleep 12
  if ! pgrep -f "gnome-panel|metacity" >/dev/null 2>&1; then
    printf '%s\n' "CGL+: GNOME Flashback components failed to start in the Codespace container. Last log lines:" >&2
    tail -n 80 "$RDP_STATE/gnome.log" 2>/dev/null || true
    tail -n 40 /tmp/cgl-rdp-metacity.log 2>/dev/null || true
    tail -n 40 /tmp/cgl-rdp-panel.log 2>/dev/null || true
    exit 1
  fi

  printf '%s\n' "[4/5] Publishing GNOME through VNC..."
  x11vnc -display "$DISPLAY_NUM" -rfbport "$VNC_PORT" -nopw -forever -shared -noxdamage -localhost >"$RDP_STATE/x11vnc.log" 2>&1 &
  echo $! >"$RDP_STATE/x11vnc.pid"
  sleep 2

  printf '%s\n' "[5/5] Starting noVNC/WebSocket gateway..."
  websockify --web="$RDP_DIR" "$WEB_PORT" 127.0.0.1:"$VNC_PORT" >"$RDP_STATE/websockify.log" 2>&1 &
  echo $! >"$RDP_STATE/websockify.pid"
  sleep 2

  if ! ss -ltn 2>/dev/null | grep -q ":$VNC_PORT "; then
    printf '%s\n' "CGL+: Codespace VNC server did not open TCP $VNC_PORT." >&2
    tail -n 40 "$RDP_STATE/x11vnc.log" 2>/dev/null || true
    exit 1
  fi
  if ! ss -ltn 2>/dev/null | grep -q ":$WEB_PORT "; then
    printf '%s\n' "CGL+: Browser gateway did not open TCP $WEB_PORT." >&2
    tail -n 40 "$RDP_STATE/websockify.log" 2>/dev/null || true
    exit 1
  fi

  printf '\n%s\n' "CGL+ LabZ | Codespace GNOME RDP Ready"
  printf '%s\n' "Desktop:  GNOME on virtual X display $DISPLAY_NUM"
  printf '%s\n' "VNC:      localhost:$VNC_PORT"
  printf '%s\n' "Web RDP:  port $WEB_PORT"
  if [ -n "${CODESPACE_NAME:-}" ]; then printf '%s\n' "Browser:  https://$CODESPACE_NAME-$WEB_PORT.app.github.dev"; else printf '%s\n' "Browser:  forward Codespace port $WEB_PORT and open the forwarded URL"; fi
  printf '\n%s\n' "The Raspberry Pi WayVNC session is completely untouched."
  exit 0
fi

if ! command -v wayvnc >/dev/null 2>&1; then
  printf '%s\n' "CGL+: wayvnc is required to share the current Wayland desktop." >&2
  printf '%s\n' "This installer intentionally does not install XFCE or a virtual desktop." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "[1/4] Installing OpenSSL..."
  as_root apt-get update
  as_root apt-get install -y openssl
else
  printf '%s\n' "[1/4] OpenSSL is already installed."
fi

printf '%s\n' "[2/4] Preparing noVNC, WebSocket proxy and Avahi..."
if ! command -v curl >/dev/null 2>&1 || ! command -v websockify >/dev/null 2>&1; then
  as_root apt-get update
  as_root apt-get install -y curl websockify avahi-daemon
else
  printf '%s\n' "CGL+: WebSocket proxy dependencies are already installed."
fi
as_root apt-mark manual wayvnc 2>/dev/null || true

printf '%s\n' "[3/4] Preserving the existing WayVNC configuration..."
as_root mkdir -p /usr/share/cgl/rdp-web
if [ -f /etc/wayvnc/config ] && [ ! -f /etc/wayvnc/config.cgl-backup ]; then
  as_root cp /etc/wayvnc/config /etc/wayvnc/config.cgl-backup
fi

as_root sh -c 'cat > /usr/share/cgl/rdp-web/index.html' <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ RDP</title>
<style>
:root{--yellow:#f2c94c;--bg:#070707;--panel:#111;--text:#f5f5f5;--muted:#9b9b9b}
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{overflow:hidden}#login{height:100%;display:grid;place-items:center;padding:24px;background:radial-gradient(circle at 50% 35%,#24200e 0,#0b0b0b 38%,#050505 100%)}
.card{width:min(420px,100%);background:rgba(17,17,17,.96);border:1px solid #292929;border-radius:24px;padding:32px;box-shadow:0 24px 80px #000}
.logo{font-weight:900;font-size:42px;letter-spacing:-2px;color:var(--yellow)}.logo span{color:#fff}
h1{font-size:25px;margin:18px 0 7px}.sub{color:var(--muted);margin:0 0 25px;line-height:1.5}
label{display:block;font-size:13px;color:#c9c9c9;margin:14px 0 7px}
input{width:100%;padding:14px 15px;border-radius:12px;border:1px solid #343434;background:#0b0b0b;color:#fff;outline:none;font-size:15px}
button{border:0;border-radius:12px;padding:13px 17px;font-weight:800;cursor:pointer}
#connect{width:100%;margin-top:22px;background:var(--yellow);color:#111;font-size:15px}
#connect:disabled{opacity:.55;cursor:wait}.note{margin-top:20px;color:#777;font-size:11px;line-height:1.45}
#desktop{display:none;width:100%;height:100%;position:relative;background:#202020}#screen{position:absolute;inset:48px 0 0;overflow:hidden}
#bar{height:48px;position:absolute;z-index:10;left:0;right:0;top:0;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#0b0b0bf2;border-bottom:1px solid #292929}
#brand{font-weight:900;color:var(--yellow);margin-right:auto}#status{font-size:12px;color:#aaa}.tool{background:#1c1c1c;color:#eee;border:1px solid #303030}
#error{display:none;margin-top:14px;padding:11px 12px;border-radius:10px;background:#2a1111;color:#ff9a9a;font-size:13px}
</style>
</head>
<body>
<section id="login"><form class="card" id="form"><div class="logo">CGL<span>+</span></div><h1>RDP</h1><p class="sub">Control the current desktop session from your browser.</p>
<label for="username">Linux Username</label><input id="username" autocomplete="username" required autofocus>
<label for="password">Linux Password</label><input id="password" type="password" autocomplete="current-password" required>
<button id="connect" type="submit">Connect</button><div id="error"></div>
<div class="note">CGL+ uses the existing WayVNC session. No XFCE or separate virtual desktop is created.</div></form></section>
<section id="desktop"><div id="bar"><div id="brand">CGL+ RDP</div><div id="status">Connecting…</div><button class="tool" id="cad">Ctrl+Alt+Del</button><button class="tool" id="disconnect">Disconnect</button></div><div id="screen"></div></section>
<script type="module">
import RFB from "/novnc/core/rfb.js";
let rfb=null,savedCredentials=null;
const login=document.getElementById("login"),desktop=document.getElementById("desktop"),form=document.getElementById("form"),connect=document.getElementById("connect"),error=document.getElementById("error"),status=document.getElementById("status"),screen=document.getElementById("screen");
function showError(message){error.textContent=message||"Connection failed.";error.style.display="block";connect.disabled=false;connect.textContent="Connect";}
function startRDP(username,password){
  savedCredentials={username,password};error.style.display="none";connect.disabled=true;connect.textContent="Connecting…";
  const scheme=location.protocol==="https:"?"wss":"ws";
  rfb=new RFB(screen,scheme+"://"+location.host+"/websockify",{shared:false});
  rfb.scaleViewport=true;rfb.clipViewport=true;rfb.resizeSession=false;
  rfb.addEventListener("connect",()=>{login.style.display="none";desktop.style.display="block";status.textContent="Connected";connect.disabled=false;connect.textContent="Connect";rfb.focus();});
  rfb.addEventListener("credentialsrequired",()=>rfb.sendCredentials(savedCredentials));
  rfb.addEventListener("securityfailure",e=>{showError(e.detail?.reason||"Authentication failed.");try{rfb.disconnect();}catch(_){}}); 
  rfb.addEventListener("disconnect",e=>{desktop.style.display="none";login.style.display="grid";connect.disabled=false;connect.textContent="Connect";status.textContent=e.detail?.clean?"Disconnected":"Connection lost";if(!e.detail?.clean&&error.style.display==="none")showError("The remote desktop disconnected.");rfb=null;});
}
form.addEventListener("submit",e=>{e.preventDefault();startRDP(document.getElementById("username").value.trim(),document.getElementById("password").value);});
document.getElementById("cad").addEventListener("click",()=>{if(rfb)rfb.sendCtrlAltDel();});
document.getElementById("disconnect").addEventListener("click",()=>{if(rfb)rfb.disconnect();});
</script>
</body>
</html>
EOF
install_novnc /usr/share/cgl/rdp-web
as_root chmod 0755 /usr/share/cgl/rdp-web
as_root chmod 0644 /usr/share/cgl/rdp-web/index.html

printf '%s\n' "[4/4] Starting the browser gateway without restarting WayVNC..."
as_root sh -c 'cat > /etc/systemd/system/cgl-rdp-web.service' <<'EOF'
[Unit]
Description=CGL+ RDP browser gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/cgl/rdp-web 1350 127.0.0.1:5900
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
as_root systemctl daemon-reload
as_root systemctl enable cgl-rdp-web.service
as_root systemctl restart cgl-rdp-web.service
as_root systemctl enable avahi-daemon 2>/dev/null || true
as_root systemctl restart avahi-daemon 2>/dev/null || true

if ! ss -ltn 2>/dev/null | grep -q ':5900 '; then
  printf '%s\n' "CGL+: Existing WayVNC is not listening on TCP 5900." >&2
  printf '%s\n' "CGL+: The browser gateway was not allowed to restart or rewrite WayVNC." >&2
  exit 1
fi

hostname_short="$(hostname -s 2>/dev/null || hostname)"
printf '\n%s\n' "CGL+ LabZ | Current Desktop RDP Ready"
printf '%s\n' "Browser:  http://$hostname_short.local:1350"
printf '%s\n' "Desktop:  existing Wayland desktop session"
printf '%s\n' "Web RDP:  port 1350"
printf '%s\n' "VNC:      localhost:5900 only"
printf '%s\n' "Auth:     Linux/PAM username + password"
printf '\n%s\n' "No XFCE or TigerVNC virtual desktop is created."
printf '%s\n' "Port 1350 is intended for trusted LAN use."
