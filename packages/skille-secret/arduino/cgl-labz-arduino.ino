/*
 * CGL+ LabZ — standalone Arduino Uno firmware
 * The Arduino independently controls the MQ-2 alarm outputs.
 * No Raspberry Pi, USB serial connection, network, or dashboard is needed
 * for sensor monitoring and local outputs.
 *
 * Optional telemetry: set ENABLE_SERIAL_TELEMETRY to true to emit one JSON
 * object per second over USB serial for an optional Pi/PC dashboard.
 * AO is a raw 10-bit ADC reading, not calibrated ppm or AQI.
 */
const byte MQ2_DO = 2;
const byte MQ2_AO = A0;
const byte LED_RED = 3;
const byte LED_YELLOW = 4;
const byte LED_GREEN = 5;
const byte BUZZER = 8;
const byte MOTOR_PWM = 9;

const bool LED_COMMON_ANODE = false;
const bool ALERT_WHEN_LOW = true;
const bool ENABLE_SERIAL_TELEMETRY = true; // Required for the live Pi dashboard; outputs work independently.
const unsigned long STARTUP_MS = 60000UL;
const unsigned long REPORT_MS = 1000UL;

unsigned long bootMs = 0;
unsigned long lastReport = 0;
unsigned long buzzerCycle = 0;

void setLed(byte pin, bool on) {
  digitalWrite(pin, LED_COMMON_ANODE ? (on ? LOW : HIGH) : (on ? HIGH : LOW));
}

void setLights(bool red, bool yellow, bool green) {
  setLed(LED_RED, red);
  setLed(LED_YELLOW, yellow);
  setLed(LED_GREEN, green);
}

void setup() {
  pinMode(MQ2_DO, INPUT);
  pinMode(MQ2_AO, INPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_YELLOW, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(MOTOR_PWM, OUTPUT);

  if (ENABLE_SERIAL_TELEMETRY) {
    Serial.begin(9600);
  }

  bootMs = millis();
  setLights(false, true, false); // Yellow during startup.
  digitalWrite(BUZZER, LOW);
  analogWrite(MOTOR_PWM, 0);
}

void loop() {
  const unsigned long now = millis();
  const bool warming = (now - bootMs) < STARTUP_MS;
  const int digitalRaw = digitalRead(MQ2_DO);
  const int analogRaw = analogRead(MQ2_AO);
  const bool alert = ALERT_WHEN_LOW ? (digitalRaw == LOW) : (digitalRaw == HIGH);
  bool buzzerOn = false;

  if (warming) {
    setLights(false, true, false);
    digitalWrite(BUZZER, LOW);
    analogWrite(MOTOR_PWM, 0);
  } else if (alert) {
    setLights(true, false, false);
    analogWrite(MOTOR_PWM, 255); // Full-speed command to the motor driver.

    if (now - buzzerCycle >= 1000UL) {
      buzzerCycle = now;
    }
    buzzerOn = (now - buzzerCycle) < 250UL;
    digitalWrite(BUZZER, buzzerOn ? HIGH : LOW);
  } else {
    setLights(false, false, true);
    digitalWrite(BUZZER, LOW);
    analogWrite(MOTOR_PWM, 0);
  }

  // USB telemetry is optional and is not involved in any control decisions.
  if (ENABLE_SERIAL_TELEMETRY && now - lastReport >= REPORT_MS) {
    lastReport = now;
    Serial.print("{\"raw\":"); Serial.print(digitalRaw);
    Serial.print(",\"ao\":"); Serial.print(analogRaw);
    Serial.print(",\"alert\":"); Serial.print((!warming && alert) ? "true" : "false");
    Serial.print(",\"warming\":"); Serial.print(warming ? "true" : "false");
    Serial.print(",\"led\":\""); Serial.print(warming ? "yellow" : (alert ? "red" : "green"));
    Serial.print("\",\"motor\":"); Serial.print((!warming && alert) ? 255 : 0);
    Serial.print(",\"buzzer\":"); Serial.print((!warming && alert && buzzerOn) ? "true" : "false");
    Serial.println("}");
  }

  (void)analogRaw; // Retained for optional telemetry and analog diagnostics.
}
