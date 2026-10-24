/*
 * CGL+ LabZ — Arduino Uno firmware
 * MQ-2 AO + DO, traffic-light LEDs, buzzer, and driver-controlled motor.
 * USB serial: one JSON object per line at 9600 baud.
 * raw = digital output (0/1); ao = analog ADC reading (0–1023).
 * These readings are not calibrated ppm/AQI measurements.
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
const unsigned long STARTUP_MS = 60000UL;
const unsigned long REPORT_MS = 1000UL;
unsigned long bootMs = 0, lastReport = 0, buzzerCycle = 0;

void setLed(byte pin, bool on) {
  digitalWrite(pin, LED_COMMON_ANODE ? (on ? LOW : HIGH) : (on ? HIGH : LOW));
}
void setLights(bool red, bool yellow, bool green) {
  setLed(LED_RED, red); setLed(LED_YELLOW, yellow); setLed(LED_GREEN, green);
}
void setup() {
  pinMode(MQ2_DO, INPUT); pinMode(MQ2_AO, INPUT);
  pinMode(LED_RED, OUTPUT); pinMode(LED_YELLOW, OUTPUT); pinMode(LED_GREEN, OUTPUT);
  pinMode(BUZZER, OUTPUT); pinMode(MOTOR_PWM, OUTPUT);
  Serial.begin(9600); bootMs = millis(); setLights(false, true, false);
  digitalWrite(BUZZER, LOW); analogWrite(MOTOR_PWM, 0);
}
void loop() {
  const unsigned long now = millis();
  const bool warming = (now - bootMs) < STARTUP_MS;
  const int digitalRaw = digitalRead(MQ2_DO);
  const int analogRaw = analogRead(MQ2_AO);
  const bool alert = ALERT_WHEN_LOW ? (digitalRaw == LOW) : (digitalRaw == HIGH);
  bool buzzerOn = false;
  if (warming) {
    setLights(false, true, false); digitalWrite(BUZZER, LOW); analogWrite(MOTOR_PWM, 0);
  } else if (alert) {
    setLights(true, false, false); analogWrite(MOTOR_PWM, 255);
    if (now - buzzerCycle >= 1000UL) buzzerCycle = now;
    buzzerOn = (now - buzzerCycle) < 250UL; digitalWrite(BUZZER, buzzerOn ? HIGH : LOW);
  } else {
    setLights(false, false, true); digitalWrite(BUZZER, LOW); analogWrite(MOTOR_PWM, 0);
  }
  if (now - lastReport >= REPORT_MS) {
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
}
