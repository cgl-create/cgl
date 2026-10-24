# CGL+ LabZ SkillExpo — Standalone AP + Arduino

This package runs a local-only dashboard on the Raspberry Pi 3 B+ and reads
sensor/output telemetry from an Arduino Uno over USB serial. The Pi creates its
own Wi-Fi access point; no school Wi-Fi, internet connection, or Cloudflare
Tunnel is needed at the expo.

## Wi-Fi and dashboard

- SSID: `CGL+ AP 1`
- Password: `CGL+LabZ-AP1`
- Security: WPA2-Personal (NetworkManager's WPA-PSK AP mode)
- Dashboard: `http://cgl-labz.local:5000`
- Direct-IP fallback: `http://192.168.4.1:5000`
- AP address: `192.168.4.1/24`; DHCP clients receive `192.168.4.20–192.168.4.200`
- No gateway or DNS server is advertised, so the AP is intended to be isolated.

The installer configures NetworkManager, dnsmasq (DHCP only), and Avahi (the
`.local` hostname). It also enables `cgl-labz-ap.service`, which unblocks Wi-Fi,
turns the radio on, and retries bringing up the saved AP profile during boot.
The dashboard service is ordered after the AP startup service. Raspberry Pi OS
must have NetworkManager managing `wlan0`.
The Pi's built-in Wi-Fi supports AP mode; a connection already using `wlan0`
will be replaced by this AP profile.

## Install/update on Raspberry Pi OS Lite

Use the CGL CLI's SkillExpo package install/update flow with the project key.
The installer installs the local services and enables the AP and dashboard at
boot. If updating a pre-existing installation, it will replace the previous
Wi-Fi profile on `wlan0` with `CGL-LabZ-AP`.

## Arduino wiring

- MQ-2 module: VCC → 5V, GND → GND, DO → D2.
- Traffic-light module: red → D3, yellow → D4, green → D5, common → GND
  for common-cathode or 5V for common-anode. Use current-limiting resistors if
  they are not built into the module.
- Buzzer control → D8 (use a driver transistor if the buzzer draws too much
  current for a GPIO pin).
- Motor-driver PWM/input → D9. Never connect a DC motor directly to an Arduino
  pin. Use a suitable motor driver or MOSFET, a suitable external motor supply,
  and a common ground; fit flyback protection for inductive loads as required.
- Connect the Arduino Uno to the Pi using a USB data cable. The Pi reads
  `/dev/ttyACM*` or `/dev/ttyUSB*` at 9600 baud.
- Do not connect MQ-2 5V logic directly to Raspberry Pi GPIO.

Open `cgl-labz-arduino.ino` in Arduino IDE, select Arduino Uno, and upload it.
The sketch emits one JSON telemetry line per second. Set `ALERT_WHEN_LOW` or
`LED_COMMON_ANODE` near the top of the sketch to match your exact modules.

## Important measurement limitation

MQ-2 DO is a threshold output, not calibrated gas concentration or ppm. The
firmware's 60-second startup indicator is only a user-interface warm-up period;
MQ-2 sensing elements require longer conditioning/burn-in. This prototype is
not a certified safety alarm.
