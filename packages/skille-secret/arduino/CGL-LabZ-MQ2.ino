/*
 * CGL+ LabZ — MQ-2 Air Quality Sensor
 * Arduino Uno firmware
 *
 * MQ-2 DO -> D2
 * MQ-2 AO -> A0
 * Red LED -> D3 (use a current-limiting resistor)
 * Green LED -> D5 (use a current-limiting resistor)
 * Buzzer -> D8 (verify its current requirement)
 *
 * No software startup delay, yellow LED, or fan.
 * Serial telemetry: newline-delimited JSON at 9600 baud.
 */

const byte MQ2_DO_PIN = 2;
const byte MQ2_AO_PIN = A0;
const byte RED_LED_PIN = 3;
const byte GREEN_LED_PIN = 5;
const byte BUZZER_PIN = 8;

// Set false if your MQ-2 module's DO output goes HIGH on alert.
const bool ALERT_WHEN_LOW = true;

const unsigned long REPORT_INTERVAL_MS = 1000UL;
const unsigned long BUZZER_INTERVAL_MS = 300UL;

unsigned long lastReport = 0;
unsigned long lastBuzzerToggle = 0;
bool buzzerState = false;

void setup() {
  pinMode(MQ2_DO_PIN, INPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);

  Serial.begin(9600);
}

void loop() {
  const unsigned long now = millis();
  const int rawDigital = digitalRead(MQ2_DO_PIN);
  const int analogValue = analogRead(MQ2_AO_PIN);

  const bool alert = ALERT_WHEN_LOW
      ? (rawDigital == LOW)
      : (rawDigital == HIGH);

  if (alert) {
    digitalWrite(RED_LED_PIN, HIGH);
    digitalWrite(GREEN_LED_PIN, LOW);

    if ((unsigned long)(now - lastBuzzerToggle) >= BUZZER_INTERVAL_MS) {
      lastBuzzerToggle = now;
      buzzerState = !buzzerState;
      digitalWrite(BUZZER_PIN, buzzerState ? HIGH : LOW);
    }
  } else {
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(GREEN_LED_PIN, HIGH);
    digitalWrite(BUZZER_PIN, LOW);
    buzzerState = false;
  }

  if ((unsigned long)(now - lastReport) >= REPORT_INTERVAL_MS) {
    lastReport = now;

    Serial.print("{\"raw\":");
    Serial.print(rawDigital);
    Serial.print(",\"ao\":");
    Serial.print(analogValue);
    Serial.print(",\"alert\":");
    Serial.print(alert ? "true" : "false");
    Serial.print(",\"warming\":false");
    Serial.print(",\"led\":\"");
    Serial.print(alert ? "red" : "green");
    Serial.print("\"");
    // Keep this field for compatibility with the current Pi dashboard.
    Serial.print(",\"motor\":0");
    Serial.print(",\"buzzer\":");
    Serial.print((alert && buzzerState) ? "true" : "false");
    Serial.println("}");
  }
}
