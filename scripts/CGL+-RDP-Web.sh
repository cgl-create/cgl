#!/bin/sh
set -eu

TARGET_LABEL="${1:-Linux}"
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

if [ "$CODESPACE_MODE" -eq 1 ]; then
  printf '%s\n' "[Codespace] Development/test environment detected."
  printf '%s\n' "CGL+: Raspberry Pi desktop services will not be started in this container."
  printf '%s\n' "CGL+: Validating the browser RDP components only."
  printf '%s\n' "[1/3] Checking OpenSSL..."
  command -v openssl >/dev/null 2>&1 || {
    printf '%s\n' "CGL+: OpenSSL is required for the RDP tooling test." >&2
    exit 1
  }
  printf '%s\n' "[2/3] Checking noVNC/WebSocket tooling..."
  command -v websockify >/dev/null 2>&1 || {
    printf '%s\n' "CGL+: websockify is required for the RDP tooling test." >&2
    exit 1
  }
  [ -d /usr/share/novnc ] || {
    printf '%s\n' "CGL+: noVNC files are required for the RDP tooling test." >&2
    exit 1
  }
  printf '%s\n' "[3/3] Checking container limitations..."
  if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    printf '%s\n' "CGL+: systemd is available, but Codespace mode will not manage services."
  else
    printf '%s\n' "CGL+: systemd is unavailable in this Codespace, as expected."
  fi
  printf '\n%s\n' "CGL+ LabZ | RDP tooling test passed"
  printf '%s\n' "Codespaces cannot host the Raspberry Pi's Wayland desktop session."
  printf '%s\n' "No WayVNC, systemd service, Avahi daemon, or desktop was modified."
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
if ! command -v websockify >/dev/null 2>&1 || [ ! -d /usr/share/novnc ]; then
  as_root apt-get update
  as_root apt-get install -y novnc websockify avahi-daemon
else
  printf '%s\n' "CGL+: noVNC and WebSocket proxy are already installed."
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
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
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
input:focus{border-color:var(--yellow);box-shadow:0 0 0 3px rgba(242,201,76,.12)}
button{border:0;border-radius:12px;padding:13px 17px;font-weight:800;cursor:pointer}
#connect{width:100%;margin-top:22px;background:var(--yellow);color:#111;font-size:15px}#connect:disabled{opacity:.55;cursor:wait}
#error{display:none;margin-top:14px;padding:11px 12px;border-radius:10px;background:#2a1111;color:#ff9a9a;font-size:13px}
.note{margin-top:20px;color:#777;font-size:11px;line-height:1.45}
#desktop{display:none;width:100%;height:100%;position:relative;background:#202020}
#screen{position:absolute;inset:48px 0 0;overflow:hidden}
#bar{height:48px;position:absolute;z-index:10;left:0;right:0;top:0;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#0b0b0bf2;border-bottom:1px solid #292929}
#brand{font-weight:900;color:var(--yellow);margin-right:auto}#status{font-size:12px;color:#aaa}
.tool{background:#1c1c1c;color:#eee;border:1px solid #303030}.tool:hover{border-color:#555}
#screen>div{width:100%!important;height:100%!important}
</style>
</head>
<body>
<section id="login">
<form class="card" id="form">
<div class="logo">CGL<span>+</span></div>
<h1>RDP</h1>
<p class="sub">Control the current desktop session from your browser.</p>
<label for="username">Linux Username</label>
<input id="username" autocomplete="username" required autofocus>
<label for="password">Linux Password</label>
<input id="password" type="password" autocomplete="current-password" required>
<button id="connect" type="submit">Connect</button>
<div id="error"></div>
<div class="note">CGL+ uses the existing WayVNC session. No XFCE or separate virtual desktop is created.</div>
</form>
</section>
<section id="desktop">
<div id="bar">
<div id="brand">CGL+ RDP</div><div id="status">Connecting…</div>
<button class="tool" id="cad">Ctrl+Alt+Del</button>
<button class="tool" id="disconnect">Disconnect</button>
</div>
<div id="screen"></div>
</section>
<script type="module">
import RFB from "/novnc/core/rfb.js";
let rfb=null,savedCredentials=null;
const login=document.getElementById("login"),desktop=document.getElementById("desktop");
const form=document.getElementById("form"),connect=document.getElementById("connect");
const error=document.getElementById("error"),status=document.getElementById("status"),screen=document.getElementById("screen");
function showError(message){error.textContent=message||"Connection failed.";error.style.display="block";connect.disabled=false;connect.textContent="Connect";}
function startRDP(username,password){
 savedCredentials={username,password}; error.style.display="none"; connect.disabled=true; connect.textContent="Connecting…";
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

if [ ! -e /usr/share/cgl/rdp-web/novnc ]; then
  as_root ln -s /usr/share/novnc /usr/share/cgl/rdp-web/novnc
fi
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
