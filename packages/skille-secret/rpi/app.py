#!/usr/bin/env python3
import asyncio,json,queue,threading,time
try:
    from bleak import BleakClient,BleakScanner
except ImportError:
    BleakClient=BleakScanner=None
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from gpiozero import LED,Buzzer,DigitalInputDevice,PWMOutputDevice

GREEN,YELLOW,RED=17,27,22
FAN,BUZZER,MQ135_DO=23,24,26
WARMUP_SECONDS=20
ALERT_WHEN_LOW=True
MICROBIT_NAME_HINTS=("micro:bit","bbc micro:bit")
UART_RX_UUID="6e400002-b5a3-f393-e0a9-e50e24dcca9e"
_ble_queue=queue.Queue(maxsize=1)
_last_ble_message=None

green=LED(GREEN); yellow=LED(YELLOW); red=LED(RED)
buzzer=Buzzer(BUZZER); fan=PWMOutputDevice(FAN,frequency=1000)
sensor=DigitalInputDevice(MQ135_DO,pull_up=False)
started=time.monotonic(); last_alert_beep=0.0; alert_phase=False

def queue_ble_message(message):
    global _last_ble_message
    if message==_last_ble_message:return
    _last_ble_message=message
    try:
        while True:_ble_queue.get_nowait()
    except queue.Empty:pass
    try:_ble_queue.put_nowait(message)
    except queue.Full:pass

async def ble_worker():
    if BleakScanner is None:
        print("CGL+ LabZ: bleak is not installed; micro:bit BLE disabled.");return
    print("CGL+ LabZ: scanning for micro:bit over Bluetooth LE...")
    while True:
        try:
            devices=await BleakScanner.discover(timeout=5.0)
            device=next((d for d in devices if any(h in (d.name or "").lower() for h in MICROBIT_NAME_HINTS)),None)
            if device is None:
                await asyncio.sleep(3);continue
            print("CGL+ LabZ: found micro:bit:",device.name or device.address)
            async with BleakClient(device) as client:
                print("CGL+ LabZ: micro:bit BLE connected.")
                while client.is_connected:
                    message=await asyncio.to_thread(_ble_queue.get)
                    await client.write_gatt_char(UART_RX_UUID,(message+"\n").encode(),response=False)
                    print("CGL+ LabZ: BLE -> micro:bit:",message)
        except Exception as exc:
            print("CGL+ LabZ: micro:bit BLE disconnected:",exc);await asyncio.sleep(3)

def start_ble():
    threading.Thread(target=lambda:asyncio.run(ble_worker()),daemon=True,name="microbit-ble").start()

def state():
    global last_alert_beep,alert_phase
    elapsed=time.monotonic()-started
    if elapsed<WARMUP_SECONDS:
        green.off();red.off();yellow.on();fan.off();buzzer.off()
        remaining=max(0,int(WARMUP_SECONDS-elapsed));queue_ble_message("WARMUP:"+str(remaining))
        return "WARMUP",remaining
    alert=(not sensor.value) if ALERT_WHEN_LOW else bool(sensor.value)
    yellow.off()
    if alert:
        red.on();green.off();fan.value=1.0
        now=time.monotonic()
        if now-last_alert_beep>=(0.25 if alert_phase else 0.75):
            alert_phase=not alert_phase;last_alert_beep=now
        buzzer.on() if alert_phase else buzzer.off();queue_ble_message("ALERT")
        return "ALERT",0
    red.off();green.on();fan.off();buzzer.off();queue_ble_message("NORMAL")
    return "NORMAL",0

PAGE='''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CGL+ LabZ | SkillExpo</title><style>body{margin:0;background:#080808;color:#f5f5f5;font:16px system-ui,sans-serif;display:grid;place-items:center;min-height:100vh}main{width:min(760px,calc(100% - 32px));padding:28px;border:1px solid #242424;border-radius:24px;background:#101010}h1{margin:0 0 6px;color:#f2c94c}.sub{color:#999}.card{margin-top:22px;padding:28px;border-radius:20px;background:#181818;text-align:center}#status{font-size:48px;font-weight:800;letter-spacing:2px}.meta{color:#aaa;margin-top:14px}.warn{margin-top:22px;padding:14px;border-radius:12px;background:#151515;color:#aaa;font-size:13px}</style></head><body><main><h1>CGL+ LabZ</h1><div class="sub">SkillExpo Air Quality Project</div><div class="card"><div id="status">CONNECTING</div><div class="meta">MQ-135 digital-threshold prototype</div></div></main></body></html>'''

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
    print("CGL+ LabZ listening on http://0.0.0.0:5000");start_ble();ThreadingHTTPServer(("0.0.0.0",5000),Handler).serve_forever()
