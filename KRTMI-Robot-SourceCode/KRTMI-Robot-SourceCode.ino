#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>

// ================= PENGATURAN WIFI & MQTT =================
const char* ssid = "POCO-X3-GT";
const char* password = "12345678910";
const char* mqtt_server = "10.133.44.216";
const int mqtt_port = 1883;

const char* topic_sub_move    = "krtmi/robot/move";
const char* topic_sub_gripper = "krtmi/robot/gripper";
const char* topic_sub_speed   = "krtmi/robot/speed";
const char* topic_sub_led     = "krtmi/robot/led";

const char* topic_pub_dist_f  = "krtmi/robot/sensor/distance_front";
const char* topic_pub_dist_r  = "krtmi/robot/sensor/distance_rear";
const char* topic_lwt         = "krtmi/robot/will";

WiFiClient espClient;
PubSubClient client(espClient);

// ================= PIN SETUP =================
// RODA
const int ENA = 19; const int IN1 = 18; const int IN2 = 5;
const int ENB = 4;  const int IN3 = 17; const int IN4 = 16;

// 🔥 SENSOR ULTRASONIK (PIN SUDAH DITUKAR)
// Jika masih tertukar, kembalikan ke: DEPAN 25, 34 & BLKNG 23, 35
const int TRIG_DEPAN = 25; const int ECHO_DEPAN = 35;
const int TRIG_BLKNG = 25; const int ECHO_BLKNG = 34; 

// INDIKATOR
const int PIN_LED = 32;
const int PIN_BUZZER = 33;

// ==================== DEKLARASI SERVO (100% ASLI) ====================
// Deklarasi Objek Servo
Servo servoBase;
Servo servoLenganDepan;
Servo servoLenganBlkng;
Servo servoGripper;

// MODE
bool modeAmbil = false; 
bool modeLetak = false;

// PIN
const int PIN_BASE      = 26;
const int PIN_DEPAN     = 27;
const int PIN_BELAKANG  = 14;
const int PIN_GRIPPER   = 12;

// STOP (hanya untuk lengan & base)
const int STOP_BASE      = 90;
const int STOP_DEPAN     = 90;
const int STOP_BELAKANG  = 90;

// ARAH
const int DEPAN_NAIK     = 0;
const int DEPAN_TURUN    = 125;

const int BLKNG_NAIK     = 180;
const int BLKNG_TURUN    = 50;

// GRIPPER
const int CAPIT_BUKA     = 60;
const int CAPIT_TUTUP    = 150; 

// WAKTU
int waktuCapitBuka     = 150;
int waktuCapitTutup    = 300;
int waktuLenganNaik    = 200;
int waktuLenganTurun   = 800;

int jedaLangkah = 500;
int jedaSiklus  = 3000;


// ================= VARIABEL STATE RODA DLL =================
int robotSpeed = 50; 
int jarakDepan = 999;
int jarakBelakang = 999;
bool forceSlowBlinkFromApp = false; 

enum MoveState { STOP, FORWARD, BACKWARD, LEFT, RIGHT };
MoveState currentMove = STOP;

unsigned long lastSensorRead = 0;
unsigned long lastMqttPub = 0;
unsigned long lastLedToggle = 0;
unsigned long lastBuzzerToggle = 0;
bool ledState = false;
bool buzzerState = false;

// ================= FUNGSI SERVO =================
// KHUSUS GRIPPER
void gerakGripper(int posisi, int durasi) {
  if (!servoGripper.attached()) {
    servoGripper.attach(PIN_GRIPPER);
  }

  servoGripper.write(posisi);
  delay(durasi);

  if (posisi == CAPIT_BUKA) {
    servoGripper.detach(); 
  }
}

// untuk lengan
void gerakDuaServo(Servo &motor1, Servo &motor2,
                   int arah1, int arah2,
                   int durasi,
                   int stop1, int stop2) {

  motor1.write(arah1);
  motor2.write(arah2);
  delay(durasi);

  motor1.write(stop1);
  motor2.write(stop2);
}

// ================= FUNGSI PERGERAKAN RODA =================
void setMotor(int in1, int in2, int in3, int in4, int pwmSpeed) {
  digitalWrite(IN1, in1); digitalWrite(IN2, in2);
  digitalWrite(IN3, in3); digitalWrite(IN4, in4);
  analogWrite(ENA, pwmSpeed); analogWrite(ENB, pwmSpeed);
}

void berhenti() { currentMove = STOP; setMotor(LOW, LOW, LOW, LOW, 0); }

// 🔥 ARAH MAJU & MUNDUR SUDAH DIBALIK SECARA SOFTWARE
void maju() {
  if (!(modeAmbil || modeLetak) && jarakDepan <= 5) return; 
  currentMove = FORWARD;
  // Semula HIGH, LOW, HIGH, LOW
  setMotor(LOW, HIGH, LOW, HIGH, map(robotSpeed, 0, 100, 0, 255));
}

void mundur() {
  if (!(modeAmbil || modeLetak) && jarakBelakang <= 5) return; 
  currentMove = BACKWARD;
  // Semula LOW, HIGH, LOW, HIGH
  setMotor(HIGH, LOW, HIGH, LOW, map(robotSpeed, 0, 100, 0, 255));
}

void kiri() {
  if (!(modeAmbil || modeLetak) && jarakDepan <= 5) return; 
  currentMove = LEFT;
  setMotor(LOW, HIGH, HIGH, LOW, map(robotSpeed, 0, 100, 0, 255));
}

void kanan() {
  if (!(modeAmbil || modeLetak) && jarakDepan <= 5) return; 
  currentMove = RIGHT;
  setMotor(HIGH, LOW, LOW, HIGH, map(robotSpeed, 0, 100, 0, 255));
}

// ================= CALLBACK MQTT =================
void callback(char* topic, byte* payload, unsigned int length) {
  String pesan = "";
  for (int i = 0; i < length; i++) pesan += (char)payload[i];
  String currentTopic = String(topic);

  if (currentTopic == topic_sub_move) {
    if (pesan == "forward") maju();
    else if (pesan == "backward") mundur();
    else if (pesan == "left") kiri();
    else if (pesan == "right") kanan();
    else if (pesan == "stop") berhenti();
  } 
  
  else if (currentTopic == topic_sub_gripper) {
    berhenti(); 
    if (pesan == "close") {
      modeAmbil = true;
      modeLetak = false;
    }
    else if (pesan == "open") {
      modeAmbil = false;
      modeLetak = true;
    }
  } 
  
  else if (currentTopic == topic_sub_speed) {
    robotSpeed = pesan.toInt();
  }
  else if (currentTopic == topic_sub_led) {
    if (pesan == "slow_blink") forceSlowBlinkFromApp = true;
    else if (pesan == "solid_on") forceSlowBlinkFromApp = false;
  }
}

// ================= PEMBACAAN SENSOR =================
long getUltrasonic(int trig, int echo) {
  digitalWrite(trig, LOW); delayMicroseconds(2);
  digitalWrite(trig, HIGH); delayMicroseconds(10);
  digitalWrite(trig, LOW);
  long duration = pulseIn(echo, HIGH, 30000); 
  if (duration == 0) return 999;
  return duration * 0.034 / 2;
}

// ================= RECONNECT =================
void reconnect() {
  if (!client.connected()) {
    String clientId = "KRTMI-ESP32-"; clientId += String(random(0xffff), HEX);
    if (client.connect(clientId.c_str(), "", "", topic_lwt, 0, false, "offline")) {
      client.publish(topic_lwt, "online");
      client.subscribe(topic_sub_move);
      client.subscribe(topic_sub_gripper);
      client.subscribe(topic_sub_speed);
      client.subscribe(topic_sub_led);
      forceSlowBlinkFromApp = false; 
    }
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  
  pinMode(ENA, OUTPUT); pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(ENB, OUTPUT); pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(TRIG_DEPAN, OUTPUT); pinMode(ECHO_DEPAN, INPUT);
  pinMode(TRIG_BLKNG, OUTPUT); pinMode(ECHO_BLKNG, INPUT);
  pinMode(PIN_LED, OUTPUT); pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  berhenti();

  // 🔥 SETUP SERVO & KALIBRASI
  ESP32PWM::allocateTimer(0);
  servoBase.attach(PIN_BASE);
  servoLenganDepan.attach(PIN_DEPAN);
  servoLenganBlkng.attach(PIN_BELAKANG);
  servoGripper.attach(PIN_GRIPPER);

  servoBase.write(STOP_BASE);

  // KALIBRASI (turun)
  gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                DEPAN_TURUN, BLKNG_TURUN,
                waktuLenganTurun,
                STOP_DEPAN, STOP_BELAKANG);
  delay(jedaLangkah);

  gerakGripper(CAPIT_BUKA, waktuCapitBuka);
  delay(2000);

  // DEFAULT (naik)
  gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                DEPAN_NAIK, BLKNG_NAIK,
                waktuLenganNaik,
                STOP_DEPAN, STOP_BELAKANG);
  delay(jedaLangkah);

  // Inisialisasi akhir -> Gripper membuka dan rileks
  gerakGripper(CAPIT_BUKA, waktuCapitBuka); 
  delay(2000);

  // KONEKSI WIFI & MQTT
  WiFi.begin(ssid, password);
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

// ================= LOOP UTAMA =================
void loop() {
  unsigned long now = millis();

  // 1. MQTT LOOP
  if (WiFi.status() == WL_CONNECTED) {
    if (!client.connected()) {
      static unsigned long lastRec = 0;
      if (now - lastRec > 5000) { lastRec = now; reconnect(); }
    } else {
      client.loop();
    }
  }

  // 2. LOGIKA SERVO
  if (modeAmbil && modeLetak) {
    // ===== AMBIL =====
    gerakGripper(CAPIT_BUKA, waktuCapitBuka);
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_TURUN, BLKNG_TURUN,
                  waktuLenganTurun,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    gerakGripper(CAPIT_TUTUP, waktuCapitTutup);
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_NAIK, BLKNG_NAIK,
                  waktuLenganNaik,
                  STOP_DEPAN, STOP_BELAKANG);

    delay(jedaLangkah);

    // ===== LANJUT LETAK =====
    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_TURUN, BLKNG_TURUN,
                  waktuLenganTurun,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    gerakGripper(CAPIT_BUKA, waktuCapitBuka);
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_NAIK, BLKNG_NAIK,
                  waktuLenganNaik,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    // Tetap biarkan terbuka (relax) di akhir proses letak
    gerakGripper(CAPIT_BUKA, waktuCapitBuka);

    delay(jedaSiklus);
    
    modeAmbil = false; modeLetak = false; 
  }
  else if (modeAmbil) {
    gerakGripper(CAPIT_BUKA, waktuCapitBuka);
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_TURUN, BLKNG_TURUN,
                  waktuLenganTurun,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    gerakGripper(CAPIT_TUTUP, waktuCapitTutup); 
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_NAIK, BLKNG_NAIK,
                  waktuLenganNaik,
                  STOP_DEPAN, STOP_BELAKANG);

    delay(jedaSiklus);
    modeAmbil = false; 
  }
  else if (modeLetak) {
    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_TURUN, BLKNG_TURUN,
                  waktuLenganTurun,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    gerakGripper(CAPIT_BUKA, waktuCapitBuka); 
    delay(jedaLangkah);

    gerakDuaServo(servoLenganDepan, servoLenganBlkng,
                  DEPAN_NAIK, BLKNG_NAIK,
                  waktuLenganNaik,
                  STOP_DEPAN, STOP_BELAKANG);
    delay(jedaLangkah);

    // Tetap biarkan terbuka (relax) di akhir proses letak
    gerakGripper(CAPIT_BUKA, waktuCapitBuka);

    delay(jedaSiklus);
    modeLetak = false; 
  }

  // 3. LED INDICATOR
  if (forceSlowBlinkFromApp || (!client.connected() && WiFi.status() == WL_CONNECTED)) {
    if (now - lastLedToggle >= 1000) {
      lastLedToggle = now; ledState = !ledState; digitalWrite(PIN_LED, ledState);
    }
  } else if (!client.connected()) {
    if (now - lastLedToggle >= 200) {
      lastLedToggle = now; ledState = !ledState; digitalWrite(PIN_LED, ledState);
    }
  } else {
    digitalWrite(PIN_LED, HIGH);
  }

  // 4. PEMBACAAN SENSOR & AUTO-STOP LOGIC
  if (now - lastSensorRead > 100) {
    lastSensorRead = now;
    jarakDepan = getUltrasonic(TRIG_DEPAN, ECHO_DEPAN);
    jarakBelakang = getUltrasonic(TRIG_BLKNG, ECHO_BLKNG);

    if (!(modeAmbil || modeLetak)) { 
      bool bahayaDepan = (jarakDepan <= 5);
      bool bahayaBelakang = (jarakBelakang <= 5);

      if (bahayaDepan && (currentMove == FORWARD || currentMove == LEFT || currentMove == RIGHT)) {
        berhenti();
      }
      if (bahayaBelakang && currentMove == BACKWARD) {
        berhenti();
      }

      if (bahayaDepan || bahayaBelakang) {
        if (now - lastBuzzerToggle >= 1000) {
          lastBuzzerToggle = now; buzzerState = !buzzerState;
          digitalWrite(PIN_BUZZER, buzzerState);
        }
      } else {
        digitalWrite(PIN_BUZZER, LOW); 
        buzzerState = false;
      }
    } else {
      digitalWrite(PIN_BUZZER, LOW); 
    }
  }

  // 5. PUBLISH DATA SENSOR
  if (now - lastMqttPub > 1000 && client.connected()) {
    lastMqttPub = now;
    client.publish(topic_pub_dist_f, String(jarakDepan).c_str());
    client.publish(topic_pub_dist_r, String(jarakBelakang).c_str());
  }
}