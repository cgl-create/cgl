/*
  CGL+ LabZ — MQ-2 Air Quality Sensor (Analog Threshold 100 Version)
  Board: Arduino UNO

  Pin Mapping:
  MQ-2 DO   -> D2
  MQ-2 AO   -> A0
  Red LED   -> D3 (through resistor)
  Green LED -> D5 (through resistor)
  Buzzer    -> D8
  Common GND

  Serial output: 9600 baud
*/

// Pin Configurations
const byte MQ2_DO = 2;
const byte MQ2_AO = A0;
const byte RED_LED = 3;
const byte GREEN_LED = 5;
const byte BUZZER = 8;

// Timing Constants
const unsigned long REPORT_INTERVAL = 1000;
const unsigned long BUZZER_INTERVAL = 300;

// Custom Sensitivity Threshold lowered to 100
const int ANALOG_THRESHOLD = 100;

// Tracking Variables
unsigned long lastReport = 0;
unsigned long lastBuzzerToggle = 0;

bool alarmActive = false;
bool buzzerState = false;

void setup() {
  // Initialize Input/Output Pins
  pinMode(MQ2_DO, INPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  // Set initial safe states (All outputs off)
  digitalWrite(RED_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
  digitalWrite(BUZZER, LOW);

  // Initialize Serial Communication for Dashboard Connection
  Serial.begin(9600);
}

void loop() {
  unsigned long now = millis();

  // Read raw values from the MQ-2 sensor
  int digitalReading = digitalRead(MQ2_DO);
  int analogReading = analogRead(MQ2_AO);

  // ALERT CONDITION: Now triggers strictly when analog reading is greater than 100
  alarmActive = (analogReading > ANALOG_THRESHOLD);

  // --- Output Peripheral Management ---
  if (alarmActive) {
    // Dangerous Air: Red LED On, Green LED Off
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW);

    // Non-blocking oscillating buzzer alarm
    if (now - lastBuzzerToggle >= BUZZER_INTERVAL) {
      lastBuzzerToggle = now;
      buzzerState = !buzzerState;
      digitalWrite(BUZZER, buzzerState ? HIGH : LOW);
    }
  } else {
    // Clean Air: Red LED Off, Green LED On, Silence Buzzer
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(BUZZER, LOW);

    // Reset buzzer state variables
    buzzerState = false;
    lastBuzzerToggle = now;
  }

  // --- Serial Output JSON Telemetry for CGL+ Dashboard ---
  if (now - lastReport >= REPORT_INTERVAL) {
    lastReport = now;

    // Outputs exact JSON packet format for the Pi to parse
    Serial.print("{\"sensor\":\"MQ-2\",\"analog\":");
    Serial.print(analogReading);
    Serial.print(",\"digital\":");
    Serial.print(digitalReading);
    Serial.print(",\"alert\":");
    Serial.print(alarmActive ? "true" : "false");
    Serial.println("}");
  }
}

