# ChefBot Registration & Hardware Setup Implementation

## Overview
This implementation connects user registration with cooker hardware setup, allowing users to:
1. Register with email/password (saved to Firebase Auth & Firestore)
2. Connect to ChefBot's WiFi access point
3. Exchange WiFi credentials and MAC address with ESP32
4. Link the cooker to their account in Firestore

## Flow Diagram

```
Registration Flow:
├─ User registers (email, password, full name)
├─ Firebase Authentication creates account
├─ User data saved to Firestore (users collection)
└─ Navigate to Initial Hardware Setup Screen

Hardware Setup Flow:
├─ User connects phone to ChefBot-XXXX WiFi
├─ Navigate to WiFi Setup Screen
├─ App gets MAC address from ESP32 (GET /mac)
├─ User enters home WiFi credentials
├─ App sends credentials to ESP32 (POST /config)
├─ Cooker data saved to Firestore (cookers collection)
│  ├─ MAC address
│  ├─ User ID (links to user)
│  └─ Cooker name
└─ Navigate to Dashboard

Login Flow:
├─ User logs in
├─ Check Firestore if user has cooker
├─ If yes → Navigate to Reconnect Welcome Screen
└─ If no → Navigate to Initial Hardware Setup Screen
```

## Firestore Database Structure

### Users Collection
```
users/
  └─ {userId}/
      ├─ uid: string
      ├─ email: string
      ├─ fullName: string
      ├─ createdAt: timestamp
      ├─ hasCooker: boolean
      ├─ cookerMacAddress: string (optional)
      └─ cookerRegisteredAt: timestamp (optional)
```

### Cookers Collection
```
cookers/
  └─ {macAddress}/
      ├─ macAddress: string
      ├─ userId: string
      ├─ cookerName: string
      ├─ registeredAt: timestamp
      └─ status: string
```

## ESP32 Web Server Requirements

Your ESP32 CAM needs to implement these endpoints when in AP mode (192.168.4.1):

### 1. GET /mac
Returns the MAC address of the ESP32.

**Response:**
```json
{
  "mac": "AA:BB:CC:DD:EE:FF"
}
```

### 2. POST /config
Receives WiFi credentials from the mobile app.

**Request Body:**
```json
{
  "ssid": "HomeWiFi",
  "password": "wifipassword123"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "WiFi configured"
}
```

The ESP32 should:
- Save the credentials
- Attempt to connect to the home WiFi
- Switch from AP mode to Station mode

### 3. GET /ping (Optional)
Simple endpoint to check if ESP32 is reachable.

**Response:**
```json
{
  "status": "ok"
}
```

### 4. GET /status (Optional)
Returns current status of the device.

**Response:**
```json
{
  "connected": true,
  "ssid": "HomeWiFi",
  "ip": "192.168.1.100"
}
```

## ESP32 Example Code (Arduino/ESP-IDF)

```cpp
#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>

WebServer server(80);

// AP credentials
const char* ap_ssid = "ChefBot-XXXX";  // Replace XXXX with last 4 digits of MAC
const char* ap_password = "12345678";   // Optional password

// Stored WiFi credentials
String stored_ssid = "";
String stored_password = "";

void setup() {
  Serial.begin(115200);
  
  // Start AP mode
  WiFi.softAP(ap_ssid, ap_password);
  Serial.println("AP Started");
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP());
  
  // Setup routes
  server.on("/mac", HTTP_GET, handleGetMac);
  server.on("/config", HTTP_POST, handlePostConfig);
  server.on("/ping", HTTP_GET, handlePing);
  server.on("/status", HTTP_GET, handleStatus);
  
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}

void handleGetMac() {
  String mac = WiFi.macAddress();
  
  StaticJsonDocument<200> doc;
  doc["mac"] = mac;
  
  String response;
  serializeJson(doc, response);
  
  server.send(200, "application/json", response);
}

void handlePostConfig() {
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    
    StaticJsonDocument<200> doc;
    deserializeJson(doc, body);
    
    stored_ssid = doc["ssid"].as<String>();
    stored_password = doc["password"].as<String>();
    
    Serial.println("Received WiFi credentials:");
    Serial.println("SSID: " + stored_ssid);
    Serial.println("Password: " + stored_password);
    
    // Send success response
    StaticJsonDocument<200> responseDoc;
    responseDoc["status"] = "success";
    responseDoc["message"] = "WiFi configured";
    
    String response;
    serializeJson(responseDoc, response);
    
    server.send(200, "application/json", response);
    
    // Connect to WiFi after a short delay
    delay(1000);
    connectToWiFi();
  } else {
    server.send(400, "application/json", "{\"error\":\"Invalid request\"}");
  }
}

void handlePing() {
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleStatus() {
  StaticJsonDocument<200> doc;
  doc["connected"] = WiFi.status() == WL_CONNECTED;
  doc["ssid"] = WiFi.SSID();
  doc["ip"] = WiFi.localIP().toString();
  
  String response;
  serializeJson(response, response);
  
  server.send(200, "application/json", response);
}

void connectToWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(stored_ssid.c_str(), stored_password.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected to WiFi!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect to WiFi");
  }
}
```

## Files Created/Modified

### New Files:
1. `lib/services/firestore_service.dart` - Handles all Firestore operations
2. `lib/services/esp32_service.dart` - Communicates with ESP32 web server
3. `lib/wifi_setup_screen.dart` - Screen for WiFi configuration

### Modified Files:
1. `pubspec.yaml` - Added cloud_firestore and http packages
2. `lib/register_screen.dart` - Now saves user data to Firestore
3. `lib/login_screen.dart` - Checks if user has cooker and navigates accordingly
4. `lib/initial_hardware_setup_screen.dart` - Navigates to WiFi setup screen
5. `lib/main.dart` - Added WiFi setup route

## Testing the Implementation

### 1. Test Registration:
- Register a new user
- Check Firebase Console → Firestore → users collection
- Verify user document is created with correct data

### 2. Test Hardware Setup (without ESP32):
- Comment out ESP32 calls temporarily for testing
- Test navigation flow through screens

### 3. Test with ESP32:
- Upload ESP32 code
- Connect phone to ChefBot-XXXX WiFi
- Go through setup flow
- Check Firestore → cookers collection
- Verify cooker is linked to user

### 4. Test Login:
- Log in with user who has cooker → should go to reconnect screen
- Log in with new user → should go to setup screen

## Security Considerations

### For Production:
1. **Enable Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can only read/write cookers linked to them
    match /cookers/{cookerId} {
      allow read, write: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
    }
  }
}
```

2. **ESP32 Security:**
- Add authentication token for ESP32 endpoints
- Use HTTPS if possible
- Implement rate limiting
- Add timeout for AP mode

3. **WiFi Password:**
- Consider encrypting WiFi password before sending
- Clear password from memory after use

## Next Steps

1. Set up Firestore security rules in Firebase Console
2. Implement ESP32 web server code
3. Test the complete flow
4. Handle edge cases (connection failures, timeouts)
5. Add reconnection logic for existing users
6. Implement cooker discovery on home network

## Error Handling

The implementation includes:
- Connection timeouts (10-15 seconds)
- User-friendly error messages
- Retry mechanisms
- Validation of inputs
- Firebase error handling

## Notes

- Default ESP32 AP IP is `192.168.4.1`
- MAC address format: `AA:BB:CC:DD:EE:FF`
- WiFi credentials are sent in plain JSON (consider encryption for production)
- User must manually connect to ChefBot AP from phone settings
