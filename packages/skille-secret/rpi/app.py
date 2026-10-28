#!/usr/bin/env python3
"""CGL+ LabZ local dashboard and Arduino serial bridge.

The Arduino owns sensor sampling and all physical outputs. The Raspberry Pi
only reads newline-delimited JSON over USB serial and serves the dashboard.
"""
import json
import os
import glob
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERIAL_BAUD = int(os.environ.get("CGL_SERIAL_BAUD", "9600"))
SERIAL_PORT = os.environ.get("CGL_SERIAL_PORT", "").strip()
HTTP_HOST = os.environ.get("CGL_HOST", "0.0.0.0")
HTTP_PORT = int(os.environ.get("CGL_PORT", "5000"))

_lock = threading.Lock()
_state = {
    "status": "CONNECTING",
    "connected": False,
    "raw": None,
    "ao": None,
    "alert": False,
    "warming": False,
    "led": "green",
    "motor": 0,
    "buzzer": False,
    "updated": None,
    "serial_port": None,
    "error": "Waiting for Arduino serial data",
}


def _candidate_ports():
    if SERIAL_PORT:
        return [SERIAL_PORT]
    found = []
    for pattern in ("/dev/ttyACM*", "/dev/ttyUSB*"):
        found.extend(glob.glob(pattern))
    return sorted(set(found))


def _serial_worker():
    """Read telemetry, tolerate reconnects, and detect stale/missing firmware output."""
    while True:
        try:
            import serial
            from serial import SerialException

            ports = _candidate_ports()
            if not ports:
                with _lock:
                    _state.update(
                        connected=False,
                        status="CONNECTING",
                        serial_port=None,
                        error="Arduino not detected; check the USB data cable",
                    )
                time.sleep(2)
                continue

            for port in ports:
                try:
                    with serial.Serial(port, SERIAL_BAUD, timeout=2) as device:
                        last_valid = None
                        with _lock:
                            _state.update(
                                connected=False,
                                status="CONNECTING",
                                serial_port=port,
                                error="Serial opened; waiting for Arduino telemetry",
                            )

                        while True:
                            line = device.readline()
                            if not line:
                                if last_valid is not None and time.monotonic() - last_valid > 8:
                                    raise SerialException(
                                        "No telemetry for 8 seconds; upload the current Arduino sketch and check 9600 baud"
                                    )
                                continue

                            try:
                                incoming = json.loads(
                                    line.decode("utf-8", errors="replace").strip()
                                )
                            except (json.JSONDecodeError, UnicodeDecodeError):
                                continue

                            if not isinstance(incoming, dict):
                                continue
                            # Accept both the current Arduino sketch's analog/digital keys and the
                            # older dashboard schema's ao/raw keys.
                            raw_value = incoming.get("raw", incoming.get("digital"))
                            ao_value = incoming.get("ao", incoming.get("analog"))
                            if raw_value is None or ao_value is None:
                                continue

                            last_valid = time.monotonic()
                            # This firmware has no software startup-delay state.
                            # Ignore stale/missing warming flags from older sketches.
                            warming = False
                            alert_value = incoming.get("alert", False)
                            if isinstance(alert_value, str):
                                alert = alert_value.strip().lower() in ("1", "true", "yes", "on")
                            else:
                                alert = bool(alert_value)
                            status = "ALERT" if alert else "NORMAL"
                            led = str(
                                incoming.get(
                                    "led",
                                    "red" if alert else "green",
                                )
                            ).lower()
                            if led not in ("red", "green"):
                                led = "red" if alert else "green"

                            try:
                                motor = max(0, min(255, int(incoming.get("motor", 0) or 0)))
                            except (TypeError, ValueError):
                                motor = 0

                            with _lock:
                                _state.update(
                                    status=status,
                                    connected=True,
                                    raw=raw_value,
                                    ao=ao_value,
                                    alert=alert,
                                    warming=warming,
                                    led=led,
                                    motor=motor,
                                    buzzer=bool(incoming.get("buzzer", alert)),
                                    updated=time.time(),
                                    serial_port=port,
                                    error=None,
                                )
                except (OSError, SerialException) as exc:
                    with _lock:
                        _state.update(
                            connected=False,
                            status="CONNECTING",
                            serial_port=port,
                            error=str(exc)[:180],
                        )
        except ImportError:
            with _lock:
                _state.update(
                    connected=False,
                    status="CONNECTING",
                    error="pyserial is not installed; install package python3-serial",
                )
            time.sleep(5)
        except Exception as exc:
            with _lock:
                _state.update(
                    connected=False,
                    status="CONNECTING",
                    error=str(exc)[:180],
                )
        time.sleep(2)


PAGE = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#080808"><title>CGL+ LabZ</title>
<style>
:root{color-scheme:dark;--gold:#f2c94c;--bg:#080808;--panel:#121212;--line:#292929;--muted:#a4a4a4}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 50% -20%,#29230d 0,transparent 48%),var(--bg);color:#f7f7f7;font:16px system-ui,-apple-system,sans-serif;min-height:100vh;display:grid;place-items:center;padding:22px}
main{width:min(780px,100%)}header{display:flex;align-items:center;gap:13px;margin-bottom:24px}.mark{width:48px;height:48px;border-radius:15px;background:var(--gold);color:#151515;display:grid;place-items:center;font-weight:950;font-size:22px}h1{margin:0;color:var(--gold);font-size:clamp(24px,5vw,34px)}.sub{color:var(--muted);font-size:14px;margin-top:3px}.pill{margin-left:auto;border:1px solid var(--line);border-radius:99px;padding:7px 11px;font-size:12px;color:var(--muted);white-space:nowrap}.dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:#777;margin-right:6px}section{border:1px solid var(--line);border-radius:24px;background:linear-gradient(145deg,#171717,#0e0e0e);padding:clamp(20px,5vw,34px);box-shadow:0 20px 70px #0008}.eyebrow{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:2px}.status{font-size:clamp(38px,10vw,64px);font-weight:850;letter-spacing:1px;margin:12px 0 4px;line-height:1.05}.detail{color:var(--muted);font-size:14px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:26px}.tile{background:#191919;border:1px solid #282828;border-radius:16px;padding:16px;min-width:0}.label{font-size:12px;color:var(--muted);margin-bottom:8px}.value{font-weight:700;font-size:18px;overflow-wrap:anywhere}.foot{font-size:12px;line-height:1.55;color:var(--muted);margin:20px 2px 0}.gold{color:var(--gold)}.red{color:#ff6262}.green{color:#66df93}.yellow{color:var(--gold)}.actions{display:flex;justify-content:flex-end;margin-top:18px}.shutdown{border:1px solid #713535;border-radius:12px;background:#291313;color:#ffb6b6;font:inherit;font-weight:700;padding:12px 16px;cursor:pointer}.shutdown:disabled{opacity:.55;cursor:wait}.shutdown-note{font-size:12px;color:var(--muted);margin-top:10px;text-align:right}@media(max-width:520px){body{padding:14px}.pill{font-size:10px;padding:6px 8px}.grid{grid-template-columns:1fr 1fr}.tile:last-child{grid-column:1/-1}.value{font-size:16px}}
</style></head><body><main>
<header><div class="mark">+</div><div><h1>CGL+ LabZ</h1><div class="sub">SkillExpo · MQ-2 gas and smoke prototype</div></div><div class="pill"><span class="dot" id="dot"></span><span id="link">Connecting</span></div></header>
<section><div class="eyebrow">Live sensor status</div><div class="status yellow" id="status">CONNECTING</div><div class="detail" id="detail">Waiting for live Arduino readings…</div>
<div class="grid"><div class="tile"><div class="label">MQ-2 analog output (AO)</div><div class="value" id="ao">— / 1023</div><div class="detail" id="aoPct">Raw ADC reading</div></div><div class="tile"><div class="label">MQ-2 digital output (DO)</div><div class="value" id="raw">—</div></div><div class="tile"><div class="label">LED status</div><div class="value" id="led">—</div></div><div class="tile"><div class="label">Outputs</div><div class="value" id="outputs">—</div></div></div>
<p class="foot">AO is a raw 10-bit ADC reading (0–1023), not calibrated concentration, ppm, or certified AQI. DO reflects the module's adjustable digital threshold. The MQ-2 module needs proper sensor conditioning. Do not use this prototype as a life-safety alarm.</p><div class="actions"><button class="shutdown" id="shutdown" type="button">Shut Down Raspberry Pi</button></div><div class="shutdown-note" id="shutdownNote">Safely powers off the Pi. The dashboard and Wi-Fi hotspot will disconnect.</div></section>
<div class="foot">Local-only dashboard · <span class="gold">CGL+ LabZ</span></div>
</main><script>
const $=id=>document.getElementById(id);
async function refresh(){try{const r=await fetch('/api/status',{cache:'no-store'});if(!r.ok)throw Error('HTTP '+r.status);const d=await r.json();
$('link').textContent=d.connected?'Arduino connected':'Arduino disconnected';$('dot').style.background=d.connected?'#66df93':'#ff6262';
const s=$('status');s.textContent=d.status;s.className='status '+(d.status==='ALERT'?'red':d.status==='NORMAL'?'green':'yellow');
$('detail').textContent=d.status==='ALERT'?'Threshold triggered · Check the area and follow expo safety procedures.':d.status==='NORMAL'?'No threshold alert reported by the module.':'Waiting for live Arduino readings.';
$('raw').textContent=d.raw===null?'—':(Number(d.raw)===0?'LOW (0)':'HIGH (1)');
$('ao').textContent=d.ao===null||d.ao===undefined?'— / 1023':Number(d.ao)+' / 1023';
$('aoPct').textContent=d.ao===null||d.ao===undefined?'Waiting for AO data':(Number(d.ao)/1023*100).toFixed(1)+'% of ADC range · raw only';
$('led').textContent=(d.led||'—').toUpperCase();$('led').className='value '+(d.led==='red'?'red':d.led==='green'?'green':'yellow');
$('outputs').textContent='Buzzer '+(d.buzzer?'ON':'OFF');
if(!d.connected&&d.error)$('detail').textContent='Serial: '+d.error;
}catch(e){$('link').textContent='Dashboard error';$('status').textContent='OFFLINE';$('status').className='status red';}}
$('shutdown').addEventListener('click',async()=>{if(!confirm('Shut down the Raspberry Pi now? The dashboard and CGL+ AP will disconnect. You will need to reconnect the power to the Pi to start it again.'))return;const b=$('shutdown'),n=$('shutdownNote');b.disabled=true;b.textContent='Shutting down…';n.textContent='Shutdown requested. Keep the Pi connected to power until its activity light settles.';try{const r=await fetch('/api/shutdown',{method:'POST',headers:{'Content-Type':'application/json'}});const d=await r.json();if(!r.ok)throw Error(d.error||'Request failed');n.textContent='Shutdown accepted. This page will disconnect shortly.';}catch(e){n.textContent='Could not confirm shutdown: '+e.message+' — check the Pi before retrying.';b.disabled=false;b.textContent='Shut Down Raspberry Pi';}});
refresh();setInterval(refresh,1000);
</script></body></html>'''


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path != "/api/shutdown":
            body = json.dumps({"error": "not found"}).encode()
            self.send_response(404)
        else:
            # Reject cross-origin browser requests; this dashboard is intended for
            # clients connected to the local, WPA-protected CGL+ AP.
            origin = self.headers.get("Origin")
            host = self.headers.get("Host", "")
            if origin and origin not in (f"http://{host}", f"https://{host}"):
                body = json.dumps({"error": "cross-origin request rejected"}).encode()
                self.send_response(403)
            else:
                body = json.dumps({"ok": True, "message": "Shutdown accepted"}).encode()
                self.send_response(202)
                threading.Thread(target=self._poweroff, daemon=True, name="safe-poweroff").start()
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    @staticmethod
    def _poweroff():
        # Give the HTTP handler time to return its acknowledgement before poweroff.
        time.sleep(2)
        os.system("/usr/bin/systemctl poweroff")

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path == "/health":
            with _lock:
                snapshot = dict(_state)
            body = json.dumps({"status": "online", "device": "cgl-labz",
                               "arduino_connected": snapshot["connected"]}).encode()
            content_type = "application/json"
        elif path == "/api/status":
            with _lock:
                snapshot = dict(_state)
            body = json.dumps(snapshot).encode()
            content_type = "application/json"
        elif path == "/":
            body = PAGE.encode()
            content_type = "text/html; charset=utf-8"
        else:
            body = b'{"error":"not found"}'
            content_type = "application/json"
            self.send_response(404)
            self.send_header("Content-Type", content_type)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    threading.Thread(target=_serial_worker, daemon=True, name="arduino-serial").start()
    print(f"CGL+ LabZ dashboard: http://{HTTP_HOST}:{HTTP_PORT}")
    print("Standalone AP: SSID CGL+ AP 1 · URL http://cgl-labz.local:5000")
    ThreadingHTTPServer((HTTP_HOST, HTTP_PORT), Handler).serve_forever()
