/*
  Blink - ESP32-C3
  LED no GPIO 8
*/

const int LED_PIN = 8;

void setup() {
  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_PIN, HIGH); // Acende o LED
  delay(2500);                  // Aguarda 2000 ms

  digitalWrite(LED_PIN, LOW);  // Apaga o LED
  delay(2500);                  // Aguarda 2000 ms
}