#!/usr/bin/env python3
import glob, json, time\ntry:\n    import serial\nexcept ImportError:\n    serial = None
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from gpiozero import LED, Buzzer, DigitalInputDevice, PWMOutputDevice

GREEN, YELLOW, RED = 17, 27, 22
FAN, BUZZER, MQ135_DO = 23, 24, 26
WARMUP_SECONDS = 20
ALERT_WHEN_LOW = True

green = LED(GREEN); yellow = LED(YELLOW); red = LED(RED)
buzzer = Buzzer(BUZZER); fan = PWMOutputDevice(FAN, frequency=1000)
sensor = DigitalInputDevice(MQ135_DO, pull_up=False)
started = time.monotonic(); last_alert_beep = 0.0; alert_phase = False\n\n# Optional micro:bit v2 display connected over USB serial.\nMICROBIT_PORTS = ("/dev/ttyACM0", "/dev/ttyACM1")\n_microbit = None\n_last_microbit = None\n\ndef microbit_write(message):\n    global _microbit, _last_microbit\n    if serial is None or message == _last_microbit:\n        return\n    if _microbit is None or not getattr(_microbit, "is_open", False):\n        for port in MICROBIT_PORTS:\n            if not glob.glob(port):\n                continue\n            try:\n                _microbit = serial.Serial(port, 115200, timeout=0.2, write_timeout=0.2)\n                break\n            except Exception:\n                _microbit = None\n    if _microbit is not None and getattr(_microbit, "is_open", False):\n        try:\n            _microbit.write((message + "\\n").encode())\n            _microbit.flush()\n            _last_microbit = message\n        except Exception:\n            try:\n                _microbit.close()\n            except Exception:\n                pass\n            _microbit = None

def state():
    global last_alert_beep, alert_phase
    elapsed = time.monotonic() - started
    if elapsed < WARMUP_SECONDS:
        green.off(); red.off(); yellow.on(); fan.off(); buzzer.off()
        remaining = max(0, int(WARMUP_SECONDS - elapsed))\n        microbit_write("WARMUP:" + str(remaining))\n        return "WARMUP", remaining
    alert = (not sensor.value) if ALERT_WHEN_LOW else bool(sensor.value)
    yellow.off()
    if alert:
        red.on(); green.off(); fan.value = 1.0
        now = time.monotonic()
        if now - last_alert_beep >= (0.25 if alert_phase else 0.75):
            alert_phase = not alert_phase; last_alert_beep = now
        buzzer.on() if alert_phase else buzzer.off()
        microbit_write("ALERT")\n        return "ALERT", 0
    red.off(); green.on(); fan.off(); buzzer.off()
    return "NORMAL", 0

PAGE = """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ LabZ | SkillExpo</title><style>
body{margin:0;background:#080808;color:#f5f5f5;font:16px system-ui,sans-serif;display:grid;place-items:center;min-height:100vh}
main{width:min(760px,calc(100% - 32px));padding:28px;border:1px solid #242424;border-radius:24px;background:#101010}
h1{margin:0 0 6px;color:#f2c94c}.sub{color:#999}.card{margin-top:22px;padding:28px;border-radius:20px;background:#181818;text-align:center}
#status{font-size:48px;font-weight:800;letter-spacing:2px}.meta{color:#aaa;margin-top:14px}
.warn{margin-top:22px;padding:14px;border-radius:12px;background:#151515;color:#aaa;font-size:13px}
</style></head><body><main><h1>CGL+ LabZ</h1><div class="sub">SkillExpo Air Quality Project</div>
<div class="card"><div id="status">CONNECTING</div><div class="meta" id="meta">Reading sensor…</div></div>
<div class="warn">MQ-135 digital-threshold prototype. This dashboard does not provide calibrated AQI or ppm values.</div></main>
<script>
async function tick(){try{let r=await fetch('/api/status',{cache:'no-store'}),d=await r.json();document.querySelector('#status').textContent=d.status;document.querySelector('#meta').textContent=d.status==='WARMUP'?'Warm-up: '+d.remaining+'s remaining':'MQ-135 digital threshold: '+(d.alert?'triggered':'not triggered')}catch(e){document.querySelector('#status').textContent='OFFLINE';document.querySelector('#meta').textContent='Waiting for CGL+ LabZ service'}}tick();setInterval(tick,1000)
</script></body></html>"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status, remaining = state()
        path = self.path.split("?", 1)[0].rstrip("/") or "/"

        # Cloudflare Tunnel forwards the complete published path to localhost:5000.
        # Match these endpoints by suffix so the app works behind:
        # /skille/path/aqs/keys/1
        # without requiring Cloudflare to strip the path.
        if path.endswith("/health"):
            body = json.dumps({
                "status": "online",
                "device": "cgl-labz",
                "timestamp": int(time.time()),
                "project_status": status,
                "remaining": remaining
            }).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if path.endswith("/api/status"):
            body = json.dumps({
                "status": status,
                "remaining": remaining,
                "alert": status == "ALERT",
                "sensor": int(sensor.value)
            }).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "frame-ancestors *")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *_): pass

if __name__ == "__main__":
    print("CGL+ LabZ listening on http://0.0.0.0:5000")
    ThreadingHTTPServer(("0.0.0.0",5000), Handler).serve_forever()
