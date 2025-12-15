# Quick Reference: Complete Registration & Hardware Setup Flow

## 📱 Mobile App Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER REGISTRATION                            │
├─────────────────────────────────────────────────────────────────┤
│ 1. User fills: Email, Password, Full Name                      │
│ 2. Firebase Auth creates account                                │
│ 3. Firestore saves user data:                                   │
│    - users/{uid}                                                │
│      • uid, email, fullName                                     │
│      • hasCooker: false                                         │
│      • createdAt: timestamp                                     │
│ 4. Navigate to: /first_time_setup                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│              INITIAL HARDWARE SETUP SCREEN                       │
├─────────────────────────────────────────────────────────────────┤
│ Instructions:                                                    │
│ 1. Plug in ChefBot                                              │
│ 2. Connect phone to "ChefBot-XXXX" WiFi                         │
│ 3. Tap "I'm Connected to ChefBot-XXXX"                          │
│ 4. Navigate to: /wifi_setup                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                   WIFI SETUP SCREEN                              │
├─────────────────────────────────────────────────────────────────┤
│ 1. GET request to ESP32: http://192.168.4.1/mac                │
│    Response: { "mac": "AA:BB:CC:DD:EE:FF" }                    │
│                                                                  │
│ 2. User enters home WiFi credentials                            │
│                                                                  │
│ 3. POST request to ESP32: http://192.168.4.1/config            │
│    Body: { "ssid": "HomeWiFi", "password": "pass123" }         │
│                                                                  │
│ 4. Save to Firestore:                                           │
│    - cookers/{macAddress}                                       │
│      • macAddress, userId, cookerName                           │
│      • registeredAt, status: "active"                           │
│    - users/{uid} update:                                        │
│      • hasCooker: true                                          │
│      • cookerMacAddress: "AA:BB:CC:DD:EE:FF"                   │
│                                                                  │
│ 5. Navigate to: /dashboard                                      │
└─────────────────────────────────────────────────────────────────┘

## 🔐 Login Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                       USER LOGIN                                 │
├─────────────────────────────────────────────────────────────────┤
│ 1. User enters: Email, Password                                 │
│ 2. Firebase Auth validates                                      │
│ 3. Check Firestore: users/{uid}.hasCooker                       │
│                                                                  │
│ If hasCooker == true:                                           │
│   → Navigate to: /reconnect_welcome                             │
│                                                                  │
│ If hasCooker == false:                                          │
│   → Navigate to: /first_time_setup                              │
└─────────────────────────────────────────────────────────────────┘
```

## 🤖 ESP32 Requirements

### Access Point Mode
- SSID: `ChefBot-XXXX` (XXXX = last 4 chars of MAC)
- IP: `192.168.4.1`

### Required Endpoints

**1. GET /mac**
```json
Response: {
  "mac": "AA:BB:CC:DD:EE:FF"
}
```

**2. POST /config**
```json
Request: {
  "ssid": "HomeWiFi",
  "password": "password123"
}
Response: {
  "status": "success",
  "message": "WiFi configured"
}
```

**3. GET /ping** (optional)
```json
Response: {
  "status": "ok"
}
```

## 📊 Firestore Database Structure

```
firestore/
├── users/
│   └── {userId}/
│       ├── uid: "abc123..."
│       ├── email: "user@example.com"
│       ├── fullName: "John Doe"
│       ├── createdAt: Timestamp
│       ├── hasCooker: false → true (after setup)
│       ├── cookerMacAddress: "AA:BB:CC:DD:EE:FF" (after setup)
│       └── cookerRegisteredAt: Timestamp (after setup)
│
└── cookers/
    └── {macAddress}/          ← MAC address as document ID
        ├── macAddress: "AA:BB:CC:DD:EE:FF"
        ├── userId: "abc123..."
        ├── cookerName: "ChefBot EE:FF"
        ├── registeredAt: Timestamp
        └── status: "active"
```

## 🛠️ Files & Services

### Services Created
1. **FirestoreService** (`lib/services/firestore_service.dart`)
   - `saveUserData()` - Save user to Firestore
   - `saveCookerData()` - Save cooker and link to user
   - `userHasCooker()` - Check if user has registered cooker
   - `getUserCookerMacAddress()` - Get user's cooker MAC
   - `getCookerDetails()` - Get cooker info by MAC
   - `getUserDetails()` - Get user info

2. **ESP32Service** (`lib/services/esp32_service.dart`)
   - `getMacAddress()` - GET http://192.168.4.1/mac
   - `sendWifiCredentials()` - POST http://192.168.4.1/config
   - `checkConnection()` - Verify ESP32 is reachable
   - `getStatus()` - Get ESP32 status

### Screens
- **RegisterScreen** - Creates Firebase Auth + Firestore user
- **InitialHardwareSetupScreen** - Instructions for AP connection
- **WifiSetupScreen** - Get MAC, send WiFi creds, save to Firestore
- **LoginScreen** - Checks hasCooker, routes accordingly

## 🧪 Testing Checklist

- [ ] Register new user → Check Firestore users collection
- [ ] User document has correct fields (hasCooker: false)
- [ ] ESP32 responds to /mac endpoint
- [ ] WiFi credentials sent successfully to ESP32
- [ ] Cooker document created in Firestore
- [ ] User document updated (hasCooker: true)
- [ ] Login with cooker → Goes to reconnect welcome
- [ ] Login without cooker → Goes to first time setup
- [ ] ESP32 connects to home WiFi after receiving credentials

## 🔒 Security Setup (Required for Production)

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /cookers/{cookerId} {
      allow read, write: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
    }
  }
}
```

### Android Permissions (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

### iOS Permissions (ios/Runner/Info.plist)
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs to connect to your ChefBot cooker on the local network</string>
```

## 🚀 Next Steps

1. **Set up Firebase Firestore**
   - Go to Firebase Console
   - Enable Firestore Database
   - Set up security rules

2. **Program ESP32**
   - Implement web server with required endpoints
   - Test endpoints with Postman/curl

3. **Test Complete Flow**
   - Register → Setup → Login

4. **Add Error Handling**
   - Connection timeouts
   - Failed WiFi setup
   - MAC address retrieval failures

5. **Implement Reconnection**
   - Search for cooker on home network
   - Update cooker status
   - Handle cooker offline scenarios
