# CGL+ LabZ SkillExpo — Arduino + optional Raspberry Pi dashboard

The Arduino Uno independently reads the MQ-2 and controls the traffic-light
LEDs, buzzer, and fan/motor driver. The Raspberry Pi is not in the physical
sensor-control loop. The Pi adds a local Wi-Fi access point and live browser
dashboard.

## Update/install the Pi dashboard

On Raspberry Pi OS Lite, run this command to fetch and execute the latest
installer directly from the repository (it does not depend on an older copy
of the CGL CLI's package script):

```sh
curl -fsSL --retry 3 'https://raw.githubusercontent.com/cgl-create/cgl/main/scripts/CGL+-SkillExpo-RPi.sh' -o /tmp/cgl-labz-install.sh && sudo sh /tmp/cgl-labz-install.sh update -key aqs-skille-key1
```

The installer updates required packages and services, downloads the dashboard,
checks its Python syntax, configures the access point and restarts the service.
If the CGL+ APT mirror is unavailable, it attempts to switch to the configured
GitHub Pages mirror. A successful install still depends on working network
access to the Raspberry Pi OS package repositories and GitHub.

After installation, the dashboard is available at:

- Wi-Fi SSID: `CGL+ AP 1`
- Wi-Fi password: `CGL+LabZ-AP1`
- Dashboard: `http://cgl-labz.local:5000`
- Direct-IP fallback: `http://192.168.4.1:5000`
- AP address: `192.168.4.1/24`; DHCP clients receive `192.168.4.20–192.168.4.200`
- No gateway or DNS server is advertised; the AP is intended to be isolated.

The Pi uses NetworkManager, dnsmasq for DHCP only, and Avahi for the `.local`
hostname. The AP supervisor retries activation every 10 seconds. Raspberry Pi
OS must have NetworkManager managing `wlan0`.

## Arduino wiring and upload

1. Open `arduino/cgl-labz-arduino.ino` in Arduino IDE.
2. Select **Arduino Uno**, choose its port, and upload the sketch.
3. Connect the Arduino to the Pi with a USB **data** cable for the live dashboard.
4. Power the Arduino and MQ-2 module; the Arduino controls local outputs even
   if the Pi, Wi-Fi, or dashboard is unavailable.

The sketch defaults to `ENABLE_SERIAL_TELEMETRY = true` so the dashboard receives
one JSON line per second at 9600 baud. Telemetry is monitoring-only and does not
control the physical outputs. Set it to `false` if you want Arduino-only
operation without USB telemetry.

### Pin map

- MQ-2 module: VCC → 5V, GND → GND, DO → D2, AO → A0.
- Traffic-light module: red → D3, yellow → D4, green → D5, common → GND
  for common-cathode or 5V for common-anode. Use current-limiting resistors if
  they are not built into the module.
- Buzzer control → D8. Use a driver transistor if the buzzer draws too much
  current for a GPIO pin.
- Motor-driver PWM/input → D9. Never connect a DC motor directly to an Arduino
  pin. Use a suitable motor driver or MOSFET, a suitable external motor supply,
  and a common ground; fit flyback protection for inductive loads as required.
- Do not connect MQ-2 5V logic directly to Raspberry Pi GPIO.

Set `ALERT_WHEN_LOW` to match the MQ-2 module's DO behavior and
`LED_COMMON_ANODE` to match the LED module. These values depend on the exact
hardware and may need adjustment.

## Measurement and safety limitations

MQ-2 DO is an adjustable threshold output, not calibrated gas concentration,
ppm, or certified AQI. The firmware's 60-second startup indicator is only a
UI warm-up period; MQ-2 sensing elements require longer conditioning/burn-in.
This prototype is not a certified life-safety alarm. Never drive a motor
directly from an Arduino pin.
