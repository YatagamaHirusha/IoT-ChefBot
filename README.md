# 🔥 ChefBot - IoT Smart Cooker System

ChefBot is an advanced IoT-enabled smart cooking system that combines ESP32-CAM hardware with Flutter mobile applications to provide real-time monitoring, control, and safety features for gas cookers.

## 🌟 Features

### 🛡️ Safety Features
- **Smoke/Fire Detection** - Real-time monitoring using MQ-2 sensor to detect smoke and fire hazards
- **Gas Leakage Detection** - MQ-5 sensor monitors for LPG/Natural gas leaks
- **Flame Verification System** - Ensures the flame is lit after ignition, automatically shuts off gas if flame goes out
- **Automatic Safety Shutoff** - Valve closes automatically when hazards are detected
- **CO Sensor Support** - Hardware support for MQ-7 CO sensor (currently disabled in firmware but can be enabled)

### 📹 Online Streaming
- **Live Video Streaming** - Real-time camera feed from ESP32-CAM at `/stream` endpoint
- **Image Capture** - On-demand image capture via `/capture` endpoint
- **Remote Monitoring** - Monitor your cooking from anywhere via mobile app

### 🎛️ Control Features
- **Remote Ignition Control** - Trigger igniter from mobile app
- **Adjustable Flame Control** - Servo-controlled valve for precise flame adjustment (0-90°)
- **Cooking Timer** - Track cooking duration with session management
- **Cooking History** - Log and review past cooking sessions with Firebase integration

### 📱 Mobile Applications
- **App1** - Main user application with hardware setup, cooker control, and monitoring
- **App2** - Alternative interface with dark theme and streamlined controls
- **User Authentication** - Firebase Authentication with email/password
- **Hardware Registration** - Easy WiFi setup and device pairing process

## 🔧 Hardware Requirements

### ESP32-CAM Board
- **Board**: ESP32-CAM (AI-Thinker)
- **Chip**: ESP32-S (ESP32-D0WDQ6 recommended)
- **Camera**: OV2640 2MP camera module
- **RAM**: 520KB SRAM + 4MB PSRAM (required for SVGA streaming)
- **Flash**: Minimum 4MB

### Arduino IDE Configuration
When programming the ESP32-CAM, use these settings in Arduino IDE:

```
Board: "AI Thinker ESP32-CAM"
CPU Frequency: "240MHz (WiFi/BT)"
Flash Frequency: "80MHz"
Flash Mode: "QIO"
Flash Size: "4MB (3MB APP/1MB SPIFFS)"
Partition Scheme: "Huge APP (3MB No OTA/1MB SPIFFS)"
Core Debug Level: "None"
Erase All Flash Before Sketch Upload: "Disabled"
Port: [Your COM Port]
```

### ESP32 Board Manager Version
- **ESP32 Board Package**: Version 2.0.0 or higher (tested with 2.0.11)
- **Installation**: In Arduino IDE, go to Tools > Board > Board Manager, search for "esp32" by Espressif Systems

### Required Arduino Libraries

Install the following libraries via Arduino Library Manager:

```
- ESP32Servo (v0.13.0 or higher)
- ArduinoJson (v6.21.0 or higher)
```

Built-in ESP32 libraries (no installation needed):
- esp_camera
- WiFi
- HTTPClient
- esp_http_server

### Sensors & Actuators
- **MQ-2** (Smoke/Fire Sensor) - Pin 13
- **MQ-5** (Gas Leakage Sensor) - Pin 15
- **Flame Sensor** - Pin 12
- **Servo Motor** (Gas valve control) - Pin 14
- **Igniter/Relay** - Pin 2
- **MQ-7** (CO Sensor) - Currently removed in firmware to prevent flash issues, but hardware-ready (was Pin 4)

### Pin Configuration (ESP32-CAM)
```cpp
Camera Pins (defined in camera_pins.h):
- PWDN:  GPIO 32
- RESET: -1
- XCLK:  GPIO 0
- SIOD:  GPIO 26
- SIOC:  GPIO 27
- Y9:    GPIO 35
- Y8:    GPIO 34
- Y7:    GPIO 39
- Y6:    GPIO 36
- Y5:    GPIO 21
- Y4:    GPIO 19
- Y3:    GPIO 18
- Y2:    GPIO 5
- VSYNC: GPIO 25
- HREF:  GPIO 23
- PCLK:  GPIO 22

Control & Sensor Pins:
- Servo (Valve):  GPIO 14
- Igniter:        GPIO 2
- Flame Sensor:   GPIO 12
- MQ-2 (Smoke):   GPIO 13
- MQ-5 (Gas):     GPIO 15
```

## 📋 Software Requirements

### ESP32 Firmware
- **Arduino IDE**: 1.8.19 or higher (or PlatformIO)
- **ESP32 Core**: 2.0.0+ by Espressif Systems

### Flutter Applications
- **Flutter SDK**: ^3.9.2
- **Dart SDK**: ^3.9.2
- **Android Studio** / **VS Code** with Flutter extensions

### Firebase Services
- Firebase Realtime Database
- Firebase Firestore
- Firebase Authentication
- Firebase Cloud Storage (optional, for cooking history images)

## 🚀 Getting Started

### 1. ESP32-CAM Setup

#### Hardware Assembly
1. Connect sensors and actuators according to the pin configuration above
2. Ensure proper power supply (5V/2A recommended) to ESP32-CAM
3. Use FTDI programmer or USB-to-TTL adapter for initial programming

#### Software Setup

1. **Install Arduino IDE and ESP32 Board Support**
   ```bash
   # In Arduino IDE:
   # File > Preferences > Additional Board Manager URLs
   # Add: https://dl.espressif.com/dl/package_esp32_index.json
   
   # Tools > Board > Board Manager
   # Search "esp32" and install "esp32 by Espressif Systems" v2.0.0+
   ```

2. **Install Required Libraries**
   ```bash
   # In Arduino IDE:
   # Tools > Manage Libraries
   # Search and install:
   # - ESP32Servo
   # - ArduinoJson
   ```

3. **Configure WiFi Credentials**
   ```cpp
   // In ChefBot_Complete.ino, update these lines:
   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";
   const String DATABASE_URL = "YOUR_FIREBASE_REALTIME_DB_URL";
   ```

4. **Upload Code**
   ```bash
   # 1. Connect ESP32-CAM to FTDI programmer
   # 2. Set GPIO 0 to GND for programming mode
   # 3. Select board: "AI Thinker ESP32-CAM"
   # 4. Select correct COM port
   # 5. Click Upload
   # 6. After upload, disconnect GPIO 0 from GND and reset
   ```

5. **Verify Operation**
   - Open Serial Monitor (115200 baud)
   - ESP32 should connect to WiFi and display IP address
   - Camera server starts on port 80 (default HTTP port)
   - Access stream at: `http://[ESP32_IP]:81/stream` (port may vary based on configuration)
   - Access capture at: `http://[ESP32_IP]/capture`
   - IP address is automatically sent to Firebase

### 2. Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use existing one
   - Enable Google Analytics (optional)

2. **Enable Firebase Services**
   ```
   - Authentication: Enable Email/Password sign-in
   - Realtime Database: Create database in asia-southeast1 (or your region)
   - Firestore: Create database
   - Storage: Enable (optional for cooking history)
   ```

3. **Configure Security Rules**

   **Realtime Database Rules:**
   ```json
   {
     "rules": {
       ".read": "auth != null",
       ".write": "auth != null"
     }
   }
   ```

   **Firestore Rules:**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth.uid == userId;
       }
       match /cookers/{cookerId} {
         allow read, write: if request.auth != null;
       }
       match /cooking_sessions/{sessionId} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

4. **Database Structure**

   **Realtime Database:**
   ```json
   {
     "camera": {
       "ip": "192.168.1.100",
       "stream_url": "http://192.168.1.100:81/stream",
       "capture_url": "http://192.168.1.100/capture"
     },
     "ignition": false,
     "valve": {
       "angle": 0
     },
     "flame": {
       "is_flame": false
     },
     "smoke": {
       "is_fire": false
     },
     "gas": {
       "is_leak": false
     },
     "CO": false
   }
   ```
   
   Note: The `stream_url` port (81 in example) may vary. The Arduino code uses port 80 by default, but your network setup may require port forwarding or different configuration.

### 3. Flutter App Setup

#### App1 (Main Application)

1. **Navigate to app1 directory**
   ```bash
   cd app1
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   
   # Select your Firebase project
   # Select platforms (Android, iOS, Web, etc.)
   ```

4. **Update Firebase Configuration**
   - The `firebase_options.dart` file will be auto-generated
   - Update `google-services.json` (Android) in `android/app/`
   - Update `GoogleService-Info.plist` (iOS) in `ios/Runner/`

5. **Run the App**
   ```bash
   # For Android
   flutter run
   
   # For iOS (macOS only)
   flutter run -d ios
   
   # For Web
   flutter run -d chrome
   ```

#### App2 (Alternative Interface)

Follow the same steps as App1 in the `app2` directory.

### 4. Mobile App Usage

1. **Registration & Setup**
   - Open the ChefBot app
   - Register with email and password
   - Follow the hardware setup wizard
   - Connect phone to ChefBot WiFi AP (if setting up for first time)
   - Enter home WiFi credentials
   - Complete cooker registration

2. **Daily Usage**
   - Login to the app
   - View live camera feed
   - Turn on ignition
   - Adjust flame level using slider
   - Monitor safety sensors in real-time
   - View cooking timer and history

## 📁 Project Structure

```
IoT-ChefBot/
├── arduino/                          # ESP32-CAM Firmware
│   ├── ChefBot_Complete.ino         # Main Arduino sketch
│   ├── app_httpd.cpp                # Camera HTTP server
│   └── camera_pins.h                # Pin definitions for ESP32-CAM
│
├── app1/                             # Flutter App 1 (Main UI)
│   ├── lib/
│   │   ├── main.dart                # App entry point
│   │   ├── login_screen.dart        # User authentication
│   │   ├── register_screen.dart     # User registration
│   │   ├── dashboard_screen.dart    # Main control interface
│   │   ├── cooking_history_screen.dart
│   │   ├── wifi_setup_screen.dart   # Hardware WiFi setup
│   │   ├── services/
│   │   │   ├── realtime_db_service.dart    # Firebase Realtime DB
│   │   │   ├── firestore_service.dart      # Firestore operations
│   │   │   ├── esp32_service.dart          # ESP32 communication
│   │   │   └── cooking_history_service.dart
│   │   └── widgets/
│   ├── pubspec.yaml                 # Flutter dependencies
│   ├── IMPLEMENTATION_GUIDE.md      # Detailed setup guide
│   └── QUICK_REFERENCE.md           # Quick reference
│
├── app2/                             # Flutter App 2 (Dark Theme)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── views/
│   │   │   ├── home_control_panel.dart
│   │   │   ├── camera_feed_view.dart
│   │   │   └── cooking_history_view.dart
│   │   └── services/
│   └── pubspec.yaml
│
└── README.md                         # This file
```

## 🔐 Security Considerations

### Production Checklist
- [ ] Change default WiFi credentials in ESP32 code
- [ ] Enable Firebase Security Rules (provided above)
- [ ] Use HTTPS for camera streaming (if possible)
- [ ] Implement rate limiting on ESP32 endpoints
- [ ] Encrypt WiFi credentials during setup transmission
- [ ] Regular firmware updates for ESP32
- [ ] Use strong passwords for Firebase Authentication

## 🐛 Troubleshooting

### ESP32-CAM Issues

**Camera fails to initialize**
- Check PSRAM is enabled and detected (`psramFound()`)
- Verify camera pin connections
- Try reducing frame size or JPEG quality
- Check power supply (camera requires stable 5V/2A)

**WiFi connection fails**
- Verify SSID and password are correct
- Check WiFi signal strength
- Ensure 2.4GHz WiFi is used (ESP32 doesn't support 5GHz)
- Try moving ESP32 closer to router

**Brownout detector triggered**
- Use adequate power supply (5V/2A minimum)
- Add capacitors near ESP32-CAM power pins
- Code includes `WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0)` to disable brownout detector

**Sensors not working**
- Verify sensor connections to correct GPIO pins
- Check sensor power supply (most MQ sensors need 5V)
- Allow MQ sensors to warm up (2-5 minutes)
- Verify pull-up/pull-down configuration

### Flutter App Issues

**Firebase connection fails**
- Verify `firebase_options.dart` is correctly configured
- Check internet connection
- Ensure Firebase project is active
- Verify `google-services.json` / `GoogleService-Info.plist` are in correct locations

**Camera stream not loading**
- Check ESP32-CAM is connected to same network
- Verify ESP32 IP address in Firebase Realtime Database
- Test stream URL directly in browser: `http://[ESP32_IP]/stream` or `http://[ESP32_IP]:81/stream`
- Note: Port may be 80 (default) or 81 depending on your network configuration
- Check firewall settings

**Build errors**
- Run `flutter clean` and `flutter pub get`
- Update Flutter SDK: `flutter upgrade`
- Check Dart/Flutter version compatibility

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is open source. Please check with the repository owner for specific license terms.

## 👨‍💻 Author

**Yatagama Hirusha**
- GitHub: [@YatagamaHirusha](https://github.com/YatagamaHirusha)

## 🙏 Acknowledgments

- ESP32 Camera examples from Espressif
- Flutter team for the excellent framework
- Firebase for backend infrastructure
- Open source community for various libraries used

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation in `app1/IMPLEMENTATION_GUIDE.md`
- Review `app1/QUICK_REFERENCE.md` for common tasks

---

**⚠️ Safety Warning**: This system controls a gas cooker. Always follow proper safety precautions:
- Never leave cooking unattended
- Ensure proper ventilation
- Keep flammable materials away from cooker
- Install and test safety sensors before use
- Have fire extinguisher nearby
- Regular maintenance of gas connections and sensors
- This system is a monitoring aid, not a replacement for proper supervision
