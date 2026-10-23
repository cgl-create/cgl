/*
 * CGL+ LabZ — Arduino Uno firmware
 * Hardware: MQ-2 digital output, 4-pin traffic-light LED module,
 * buzzer, and a DC motor connected through a driver/MOSFET.
 *
 * USB serial protocol: one JSON object per line at 9600 baud.
 * The Raspberry Pi reads telemetry only; this sketch owns all hardware outputs.
 */
const byte MQ2_DO = 2;
const byte LED_RED = 3;
const byte LED_YELLOW = 4;
const byte LED_GREEN = 5;
const byte BUZZER = 8;
const byte MOTOR_PWM = 9;

// Set true for a common-anode LED module. Common-cathode is the default.
const bool LED_COMMON_ANODE = false;
// Many MQ-2 modules pull DO LOW when their threshold is crossed.
// Flip this setting if your particular module behaves the other way.
const bool ALERT_WHEN_LOW = true;
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
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_YELLOW, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(MOTOR_PWM, OUTPUT);
  Serial.begin(9600);
  bootMs = millis();
  setLights(false, true, false);
  digitalWrite(BUZZER, LOW);
  analogWrite(MOTOR_PWM, 0);
}

void loop() {
  const unsigned long now = millis();
  const bool warming = (now - bootMs) < STARTUP_MS;
  const int raw = digitalRead(MQ2_DO);
  const bool alert = ALERT_WHEN_LOW ? (raw == LOW) : (raw == HIGH);
  bool buzzerOn = false;

  if (warming) {
    setLights(false, true, false);
    digitalWrite(BUZZER, LOW);
    analogWrite(MOTOR_PWM, 0);
  } else if (alert) {
    setLights(true, false, false);
    analogWrite(MOTOR_PWM, 255);
    if (now - buzzerCycle >= 1000UL) buzzerCycle = now;
    buzzerOn = (now - buzzerCycle) < 250UL;
    digitalWrite(BUZZER, buzzerOn ? HIGH : LOW);
  } else {
    setLights(false, false, true);
    digitalWrite(BUZZER, LOW);
    analogWrite(MOTOR_PWM, 0);
  }

  if (now - lastReport >= REPORT_MS) {
    lastReport = now;
    Serial.print("{\"raw\":"); Serial.print(raw);
    Serial.print(",\"alert\":"); Serial.print((!warming && alert) ? "true" : "false");
    Serial.print(",\"warming\":"); Serial.print(warming ? "true" : "false");
    Serial.print(",\"led\":\""); Serial.print(warming ? "yellow" : (alert ? "red" : "green"));
    Serial.print("\",\"motor\":"); Serial.print((!warming && alert) ? 255 : 0);
    Serial.print(",\"buzzer\":"); Serial.print((!warming && alert && buzzerOn) ? "true" : "false");
    Serial.println("}");
  }
}
