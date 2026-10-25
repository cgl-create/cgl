# CGL+ LabZ SkillExpo — Arduino + optional Raspberry Pi dashboard

The Arduino Uno runs the MQ-2 threshold response and controls the traffic-light
LEDs, buzzer, and fan/motor driver on its own. **The Raspberry Pi is not needed
for local sensing or outputs.** The Pi is optional and adds a Wi-Fi access point
and live browser dashboard.

## Standalone Arduino mode

1. Wire the components as described below.
2. Open `arduino/cgl-labz-arduino.ino` in Arduino IDE, select **Arduino Uno**,
   and upload it.
3. Power the Arduino and sensor from a suitable supply. After startup, the
   Arduino controls the outputs automatically; no USB connection to a Pi or PC
   is required.

The sketch defaults to `ENABLE_SERIAL_TELEMETRY = false`. For an optional
Pi/PC dashboard, set it to `true`, then connect USB serial at 9600 baud.
Telemetry is monitoring-only and does not control the outputs.

## Optional Pi Wi-Fi dashboard

- SSID: `CGL+ AP 1`
- Password: `CGL+LabZ-AP1`
- Security: WPA2-Personal (NetworkManager's WPA-PSK AP mode)
- Dashboard: `http://cgl-labz.local:5000`
- Direct-IP fallback: `http://192.168.4.1:5000`
- AP address: `192.168.4.1/24`; DHCP clients receive `192.168.4.20–192.168.4.200`
- No gateway or DNS server is advertised; the AP is intended to be isolated.

The Pi uses NetworkManager, dnsmasq (DHCP only), and Avahi (the `.local`
hostname). Its `cgl-labz-ap.service` supervisor attempts to activate the saved
AP profile and checks every 10 seconds to recover if the connection drops.
The dashboard service starts after the AP supervisor. Raspberry Pi OS must
have NetworkManager managing `wlan0`.

Install/update the optional Pi services through the CGL CLI's SkillExpo package
flow. The Pi creates the Wi-Fi AP and reads the Arduino's USB telemetry; it is
not in the sensor-control loop.

## Arduino wiring

- MQ-2 module: VCC → 5V, GND → GND, DO → D2, AO → A0.
- Traffic-light module: red → D3, yellow → D4, green → D5, common → GND
  for common-cathode or 5V for common-anode. Use current-limiting resistors if
  they are not built into the module.
- Buzzer control → D8. Use a driver transistor if the buzzer draws too much
  current for a GPIO pin.
- Motor-driver PWM/input → D9. Never connect a DC motor directly to an Arduino
  pin. Use a suitable motor driver or MOSFET, a suitable external motor supply,
  and a common ground; fit flyback protection for inductive loads as required.
- Optional dashboard only: connect the Arduino to the Pi with a USB data cable.
  The Pi reads `/dev/ttyACM*` or `/dev/ttyUSB*` at 9600 baud.
- Do not connect MQ-2 5V logic directly to Raspberry Pi GPIO.

Set `ALERT_WHEN_LOW` to match the MQ-2 module's DO behavior and
`LED_COMMON_ANODE` to match the LED module. These values may need adjustment
for the exact hardware.

## Important measurement and safety limitations

MQ-2 DO is an adjustable threshold output, not calibrated gas concentration,
ppm, or certified AQI. The firmware's 60-second startup indicator is only a
UI warm-up period; MQ-2 sensing elements require longer conditioning/burn-in.
This prototype is not a certified life-safety alarm. Never drive a motor
directly from an Arduino pin.
