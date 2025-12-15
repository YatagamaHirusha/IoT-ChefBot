#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "camera_pins.h"

// ===========================
// CONFIGURATION
// ===========================
const char* ssid = "Redmi Note 12";
const char* password = "000000000";
const String DATABASE_URL = "https://chefbot-smartcooker-default-rtdb.asia-southeast1.firebasedatabase.app/";

// ===========================
// PIN DEFINITIONS
// ===========================
// Actuators
#define SERVO_PIN   14  
#define IGNITER_PIN 2   

// Sensors
// Pin 12 is the Flame Sensor
// REMOVED MQ7 (Pin 4) to stop the Flashlight issue
#define FLAME_PIN   12 
#define MQ2_PIN     13 
#define MQ5_PIN     15  

// ===========================
// GLOBALS
// ===========================
Servo valveServo;
unsigned long lastFirebaseUpdate = 0;
const long FIREBASE_INTERVAL = 2000; 

// Function Declarations
void startCameraServer();

// ===========================
// FIREBASE FUNCTIONS
// ===========================

void sendCameraDataToFirebase(String ip) {
  if(WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  String path = DATABASE_URL + "camera.json"; 
  String data = "{\"ip\":\"" + ip + "\",\"stream_url\":\"http://" + ip + "/stream\",\"capture_url\":\"http://" + ip + "/capture\"}";
  
  http.begin(path);
  http.addHeader("Content-Type", "application/json");
  http.PUT(data);
  http.end();
}

void updateSensorFirebase(bool flame, bool smoke, bool gas, bool co) {
  if(WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  String path = DATABASE_URL + ".json"; 
  
  // JSON construction
  String data = "{\"flame\":{\"is_flame\":" + String(flame ? "true" : "false") +
                "},\"smoke\":{\"is_fire\":" + String(smoke ? "true" : "false") +
                "},\"gas\":{\"is_leak\":" + String(gas ? "true" : "false") +
                "},\"CO\":" + String(co ? "true" : "false") + "}"; // CO is always false now
                
  http.begin(path);
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(data); 
  http.end();
}

void fetchFirebaseCommands() {
  if(WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  String path = DATABASE_URL + ".json";
  
  http.begin(path);
  int httpCode = http.GET();
  if(httpCode == 200){
    String payload = http.getString();
    StaticJsonDocument<1024> doc;
    DeserializationError error = deserializeJson(doc, payload);
    if(!error){
      if(doc.containsKey("valve")){
        int angle = doc["valve"]["angle"] | 0;
        valveServo.write(angle);
      }
      if(doc.containsKey("ignition")){
        bool ignitionState = doc["ignition"] | false;
        digitalWrite(IGNITER_PIN, ignitionState ? HIGH : LOW);
      }
    }
  }
  http.end();
}

// ===========================
// MAIN SETUP
// ===========================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); 
  Serial.begin(115200);
  
  // 1. WiFi Connection
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");

  // 2. Camera Configuration
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  
  if(psramFound()){
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 10;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  // Camera Init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // 3. Start Camera Server
  startCameraServer();
  Serial.print("Camera Ready! IP: ");
  Serial.println(WiFi.localIP());

  // 4. Send IP to Firebase
  sendCameraDataToFirebase(WiFi.localIP().toString());

  // 5. Setup Sensors
  pinMode(IGNITER_PIN, OUTPUT);
  pinMode(FLAME_PIN, INPUT_PULLDOWN);
  pinMode(MQ2_PIN, INPUT_PULLDOWN);
  pinMode(MQ5_PIN, INPUT_PULLDOWN);
  // MQ7 SETUP REMOVED

  // 6. Setup Servo
  valveServo.attach(SERVO_PIN);
  valveServo.write(0); 
}

// ===========================
// MAIN LOOP
// ===========================
void loop() {
  if (millis() - lastFirebaseUpdate > FIREBASE_INTERVAL) {
    lastFirebaseUpdate = millis();

    // ============================================================
    // CHANGED: Removed the '!' from flame.
    // If it was reading TRUE before, removing '!' should make it FALSE (Safe).
    // ============================================================
    bool flame = digitalRead(FLAME_PIN); 
    bool smoke = !digitalRead(MQ2_PIN); // Keep '!' if this one is working correctly
    bool gas   = !digitalRead(MQ5_PIN); // Keep '!' if this one is working correctly
    
    // We pass 'false' for the CO (MQ7) value since the sensor is removed
    updateSensorFirebase(flame, smoke, gas, false); 
    
    fetchFirebaseCommands();
    
    Serial.printf("Status -> Flame:%d Smoke:%d Gas:%d\n", flame, smoke, gas);
  }
  
  delay(10); 
}