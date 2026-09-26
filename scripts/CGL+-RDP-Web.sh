#!/bin/sh
set -eu

TARGET_LABEL="${1:-Linux}"

clear
printf '%s\n' "CGL+ LabZ | Current Desktop Browser RDP"
printf '%s\n\n' "Configuring CGL+ RDP for $TARGET_LABEL..."

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf '%s\n' "CGL+: root privileges are required." >&2
    exit 1
  fi
}

if ! command -v wayvnc >/dev/null 2>&1; then
  printf '%s\n' "CGL+: wayvnc is required to share the current Wayland desktop." >&2
  printf '%s\n' "This installer intentionally does not install XFCE or a virtual desktop." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "[1/5] Installing OpenSSL..."
  as_root apt-get update
  as_root apt-get install -y openssl
else
  printf '%s\n' "[1/5] OpenSSL is already installed."
fi

printf '%s\n' "[2/5] Preparing noVNC, WebSocket proxy and Avahi..."
as_root apt-get update
as_root apt-get install -y novnc websockify avahi-daemon

printf '%s\n' "[3/5] Configuring WayVNC to share the current desktop..."

as_root mkdir -p /etc/wayvnc /usr/share/cgl/rdp-web
if [ -f /etc/wayvnc/config ] && [ ! -f /etc/wayvnc/config.cgl-backup ]; then
  as_root cp /etc/wayvnc/config /etc/wayvnc/config.cgl-backup
fi

if [ ! -f /etc/wayvnc/cgl-rdp-key.pem ] || [ ! -f /etc/wayvnc/cgl-rdp-cert.pem ]; then
  as_root openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -sha256 \
    -days 825 -nodes \
    -keyout /etc/wayvnc/cgl-rdp-key.pem \
    -out /etc/wayvnc/cgl-rdp-cert.pem \
    -subj "/CN=$(hostname -f 2>/dev/null || hostname)"
  as_root chmod 0600 /etc/wayvnc/cgl-rdp-key.pem
  as_root chmod 0644 /etc/wayvnc/cgl-rdp-cert.pem
fi

as_root sh -c 'cat > /etc/wayvnc/config' <<'EOF'
address=127.0.0.1
port=5900
enable_auth=true
enable_pam=true
private_key_file=/etc/wayvnc/cgl-rdp-key.pem
certificate_file=/etc/wayvnc/cgl-rdp-cert.pem
relax_encryption=true
EOF

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
 rfb=new RFB(screen,scheme+"://"+location.host+"/websockify",{shared:false,credentials:savedCredentials});
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

printf '%s\n' "[4/5] Creating the CGL+ browser gateway..."
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

printf '%s\n' "[5/5] Restarting the existing WayVNC desktop session..."
as_root systemctl daemon-reload
as_root systemctl enable cgl-rdp-web.service
as_root systemctl restart cgl-rdp-web.service
as_root systemctl enable avahi-daemon
as_root systemctl restart avahi-daemon

if command -v pkill >/dev/null 2>&1; then
  as_root pkill -x wayvnc 2>/dev/null || true
fi

sleep 2

if ! ss -ltn 2>/dev/null | grep -q ':5900 '; then
  printf '%s\n' "CGL+: WayVNC did not return on TCP 5900 after restart." >&2
  printf '%s\n' "Your desktop's existing WayVNC launcher may need to be restarted from the desktop session." >&2
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
