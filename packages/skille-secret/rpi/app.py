#!/usr/bin/env python3
import json,threading,time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from gpiozero import LED,Buzzer,DigitalInputDevice,PWMOutputDevice

GREEN,YELLOW,RED=17,27,22
FAN,BUZZER,MQ2_DO=23,24,26
WARMUP_SECONDS=20
ALERT_WHEN_LOW=True

green=LED(GREEN); yellow=LED(YELLOW); red=LED(RED)
buzzer=Buzzer(BUZZER); fan=PWMOutputDevice(FAN,frequency=1000)
sensor=DigitalInputDevice(MQ2_DO,pull_up=False)
started=time.monotonic(); last_alert_beep=0.0; alert_phase=False

def state():
    global last_alert_beep,alert_phase
    elapsed=time.monotonic()-started
    if elapsed<WARMUP_SECONDS:
        green.off();red.off();yellow.on();fan.off();buzzer.off()
        return "WARMUP",max(0,int(WARMUP_SECONDS-elapsed))
    alert=(not sensor.value) if ALERT_WHEN_LOW else bool(sensor.value)
    yellow.off()
    if alert:
        red.on();green.off();fan.value=1.0
        now=time.monotonic()
        if now-last_alert_beep>=(0.25 if alert_phase else 0.75):
            alert_phase=not alert_phase;last_alert_beep=now
        buzzer.on() if alert_phase else buzzer.off()
        return "ALERT",0
    red.off();green.on();fan.off();buzzer.off()
    return "NORMAL",0

PAGE='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ LabZ | SkillExpo</title><style>body{margin:0;background:#080808;color:#f5f5f5;font:16px system-ui,sans-serif;display:grid;place-items:center;min-height:100vh}main{width:min(760px,calc(100% - 32px));padding:28px;border:1px solid #242424;border-radius:24px;background:#101010}h1{margin:0 0 6px;color:#f2c94c}.sub{color:#999}.card{margin-top:22px;padding:28px;border-radius:20px;background:#181818;text-align:center}#status{font-size:48px;font-weight:800;letter-spacing:2px}.meta{color:#aaa;margin-top:14px}.warn{margin-top:22px;padding:14px;border-radius:12px;background:#151515;color:#aaa;font-size:13px}</style></head><body><main><h1>CGL+ LabZ</h1><div class="sub">SkillExpo Smoke and Gas Detection Project</div><div class="card"><div id="status">CONNECTING</div><div class="meta">MQ-2 digital-threshold prototype</div><div class="warn">This prototype reports the MQ-2 module's digital threshold state. It does not measure calibrated gas concentration or ppm and is not a certified safety alarm.</div></div><script>async function refresh(){try{const r=await fetch('./api/status',{cache:'no-store'});const d=await r.json();const s=document.getElementById('status');s.textContent=d.status+(d.status==='WARMUP'?' '+d.remaining+'s':'');s.style.color=d.status==='ALERT'?'#ff5252':d.status==='NORMAL'?'#55df83':'#f2c94c'}catch(e){document.getElementById('status').textContent='OFFLINE'}}refresh();setInterval(refresh,1000)</script></main></body></html>'''

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status,remaining=state();path=self.path.split("?",1)[0].rstrip("/") or "/"
        if path.endswith("/health"):
            body=json.dumps({"status":"online","device":"cgl-labz","project_status":status,"remaining":remaining}).encode()
            self.send_response(200);self.send_header("Content-Type","application/json");self.send_header("Cache-Control","no-store");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body);return
        if path.endswith("/api/status"):
            body=json.dumps({"status":status,"remaining":remaining,"alert":status=="ALERT","sensor":int(sensor.value)}).encode()
            self.send_response(200);self.send_header("Content-Type","application/json");self.send_header("Cache-Control","no-store");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body);return
        body=PAGE.encode();self.send_response(200);self.send_header("Content-Type","text/html; charset=utf-8");self.send_header("Cache-Control","no-store");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
    def log_message(self,*_):pass

if __name__=="__main__":
    print("CGL+ LabZ listening on http://0.0.0.0:5000")
    ThreadingHTTPServer(("0.0.0.0",5000),Handler).serve_forever()
