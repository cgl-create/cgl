#!/bin/sh
set -eu

TARGET_LABEL="${1:-Linux}"

clear
printf '%s\n' "CGL+ LabZ | Browser Remote Desktop Setup"
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

if [ "$(id -u)" -eq 0 ]; then
  target_user="$(logname 2>/dev/null || true)"
  [ -n "$target_user" ] || target_user="${SUDO_USER:-}"
else
  target_user="${USER:-$(id -un)}"
fi

[ -n "$target_user" ] || {
  printf '%s\n' "CGL+: could not determine the Linux user for the RDP session." >&2
  exit 1
}

if [ "$target_user" = "root" ]; then
  printf '%s\n' "CGL+: root is not supported as the browser RDP session user." >&2
  printf '%s\n' "Create/use a normal Linux user and run CGL+ again." >&2
  exit 1
fi

printf '%s\n' "[1/6] Installing desktop, RDP and browser-VNC components..."
as_root apt-get update
as_root apt-get install -y xfce4 xfce4-goodies dbus-x11 xrdp tigervnc-standalone-server tigervnc-common novnc websockify avahi-daemon

printf '\n%s\n' "[2/6] Setting the Linux account password..."
printf '%s\n' "The browser login uses the Linux username and password."
printf '%s\n\n' "Set or change the password for: $target_user"
as_root passwd "$target_user"

printf '\n%s\n' "[3/6] Preparing the CGL+ browser interface..."
as_root mkdir -p /usr/share/cgl/rdp-web
as_root sh -c 'cat > /usr/share/cgl/rdp-web/index.html' <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ RDP</title>
<style>
:root{--yellow:#f2c94c;--bg:#070707;--panel:#111;--text:#f5f5f5;--muted:#9b9b9b}
*{box-sizing:border-box}
html,body{margin:0;width:100%;height:100%;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{overflow:hidden}
#login{height:100%;display:grid;place-items:center;padding:24px;background:radial-gradient(circle at 50% 35%,#24200e 0,#0b0b0b 38%,#050505 100%)}
.card{width:min(420px,100%);background:rgba(17,17,17,.96);border:1px solid #292929;border-radius:24px;padding:32px;box-shadow:0 24px 80px #000}
.logo{font-weight:900;font-size:42px;letter-spacing:-2px;color:var(--yellow)}
.logo span{color:#fff}
h1{font-size:25px;margin:18px 0 7px}
.sub{color:var(--muted);margin:0 0 25px;line-height:1.5}
label{display:block;font-size:13px;color:#c9c9c9;margin:14px 0 7px}
input{width:100%;padding:14px 15px;border-radius:12px;border:1px solid #343434;background:#0b0b0b;color:#fff;outline:none;font-size:15px}
input:focus{border-color:var(--yellow);box-shadow:0 0 0 3px rgba(242,201,76,.12)}
button{border:0;border-radius:12px;padding:13px 17px;font-weight:800;cursor:pointer}
#connect{width:100%;margin-top:22px;background:var(--yellow);color:#111;font-size:15px}
#connect:disabled{opacity:.55;cursor:wait}
#error{display:none;margin-top:14px;padding:11px 12px;border-radius:10px;background:#2a1111;color:#ff9a9a;font-size:13px}
.note{margin-top:20px;color:#777;font-size:11px;line-height:1.45}
#desktop{display:none;width:100%;height:100%;position:relative;background:#202020}
#screen{position:absolute;inset:48px 0 0;overflow:hidden}
#bar{height:48px;position:absolute;z-index:10;left:0;right:0;top:0;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#0b0b0bf2;border-bottom:1px solid #292929}
#brand{font-weight:900;color:var(--yellow);margin-right:auto}
#status{font-size:12px;color:#aaa}
.tool{background:#1c1c1c;color:#eee;border:1px solid #303030}
.tool:hover{border-color:#555}
#screen>div{width:100%!important;height:100%!important}
</style>
</head>
<body>
<section id="login">
  <form class="card" id="form">
    <div class="logo">CGL<span>+</span></div>
    <h1>RDP</h1>
    <p class="sub">Browser Remote Desktop. Sign in with a Linux user account to control this machine.</p>
    <label for="username">Username</label>
    <input id="username" name="username" autocomplete="username" required autofocus>
    <label for="password">Password</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required>
    <button id="connect" type="submit">Connect</button>
    <div id="error"></div>
    <div class="note">CGL+ RDP uses noVNC in the browser and TigerVNC on the host. Keep port 1350 on a trusted network unless you add HTTPS/TLS at the proxy.</div>
  </form>
</section>
<section id="desktop">
  <div id="bar">
    <div id="brand">CGL+ RDP</div>
    <div id="status">Connecting…</div>
    <button class="tool" id="cad">Ctrl+Alt+Del</button>
    <button class="tool" id="disconnect">Disconnect</button>
  </div>
  <div id="screen"></div>
</section>
<script type="module">
import RFB from "/novnc/core/rfb.js";
let rfb=null, savedCredentials=null;
const login=document.getElementById("login"), desktop=document.getElementById("desktop");
const form=document.getElementById("form"), connect=document.getElementById("connect");
const error=document.getElementById("error"), status=document.getElementById("status");
const screen=document.getElementById("screen");
function showError(message){
  error.textContent=message||"Connection failed.";
  error.style.display="block";
  connect.disabled=false;
  connect.textContent="Connect";
}
function startRDP(username,password){
  savedCredentials={username,password};
  error.style.display="none";
  connect.disabled=true;
  connect.textContent="Connecting…";
  const scheme=location.protocol==="https:"?"wss":"ws";
  const url=scheme+"://"+location.host+"/websockify";
  rfb=new RFB(screen,url,{shared:false,credentials:savedCredentials});
  rfb.scaleViewport=true;
  rfb.clipViewport=true;
  rfb.resizeSession=true;
  rfb.addEventListener("connect",()=>{
    login.style.display="none";
    desktop.style.display="block";
    status.textContent="Connected";
    connect.disabled=false;
    connect.textContent="Connect";
    rfb.focus();
  });
  rfb.addEventListener("credentialsrequired",()=>rfb.sendCredentials(savedCredentials));
  rfb.addEventListener("securityfailure",(event)=>{
    showError(event.detail?.reason||"Authentication failed.");
    try{rfb.disconnect();}catch(_){}
    rfb=null;
  });
  rfb.addEventListener("disconnect",(event)=>{
    desktop.style.display="none";
    login.style.display="grid";
    connect.disabled=false;
    connect.textContent="Connect";
    status.textContent=event.detail?.clean?"Disconnected":"Connection lost";
    if(!event.detail?.clean&&error.style.display==="none")
      showError("The remote desktop disconnected. Check the username, password, and CGL+ RDP service.");
    rfb=null;
  });
}
form.addEventListener("submit",(event)=>{
  event.preventDefault();
  startRDP(document.getElementById("username").value.trim(),document.getElementById("password").value);
});
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

printf '\n%s\n' "[4/6] Creating the CGL+ virtual desktop service..."
home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
as_root sh -c "cat > /etc/systemd/system/cgl-rdp-vnc.service" <<EOF
[Unit]
Description=CGL+ RDP virtual desktop
After=network.target

[Service]
Type=simple
User=$target_user
Environment=HOME=$home_dir
WorkingDirectory=$home_dir
ExecStart=/usr/bin/tigervncserver :1 -fg -geometry 1280x720 -localhost yes -SecurityTypes Plain -PlainUsers $target_user -PAMService tigervnc -- xfce
ExecStop=/usr/bin/tigervncserver -kill :1
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

printf '\n%s\n' "[5/6] Creating the CGL+ web proxy on port 1350..."
as_root sh -c "cat > /etc/systemd/system/cgl-rdp-web.service" <<'EOF'
[Unit]
Description=CGL+ RDP browser gateway
After=network-online.target cgl-rdp-vnc.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/cgl/rdp-web 1350 localhost:5901
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

printf '\n%s\n' "[6/6] Starting CGL+ RDP services..."
as_root systemctl daemon-reload
as_root systemctl enable cgl-rdp-vnc.service
as_root systemctl enable cgl-rdp-web.service
as_root systemctl restart cgl-rdp-vnc.service
as_root systemctl restart cgl-rdp-web.service
as_root systemctl enable xrdp
as_root systemctl restart xrdp
as_root systemctl enable avahi-daemon
as_root systemctl restart avahi-daemon

hostname_short="$(hostname -s 2>/dev/null || hostname)"
printf '\n%s\n' "CGL+ LabZ | Browser RDP Setup Complete"
printf '%s\n' "Browser:  http://$hostname_short.local:1350"
printf '%s\n' "Username: $target_user"
printf '%s\n' "RDP:      port 3389 (native RDP client)"
printf '%s\n' "Web RDP:  port 1350 (CGL+ browser/noVNC)"
printf '%s\n' "Desktop:  XFCE virtual desktop"
printf '%s\n' "Authentication: Linux username + password"
printf '\n%s\n' "Port 1350 is intended for trusted LAN use. Add HTTPS/TLS before exposing it beyond your LAN."
