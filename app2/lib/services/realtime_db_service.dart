import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

class RealtimeDBService {
  static final RealtimeDBService _instance = RealtimeDBService._internal();

  factory RealtimeDBService() {
    return _instance;
  }

  RealtimeDBService._internal();

  DatabaseReference? _dbRef;

  DatabaseReference get _ref {
    // Ensure you update the databaseURL to match your Firebase console if needed
    _dbRef ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://chefbot-smartcooker-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref();
    return _dbRef!;
  }

  Future<Map<String, String>> getCameraConfig() async {
    // Returning hardcoded config as per your App 1 setup
    return {
      'stream_url': 'http://10.171.122.237/stream',
      'capture_url': 'http://10.171.122.237/capture',
    };
  }

  // ============ Gas Cooker Control Methods ============

  Future<void> triggerIgnition() async {
    try {
      await _ref.child('ignition').set(true);
      // Automatically set back to false after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      await _ref.child('ignition').set(false);
    } catch (e) {
      print('Error triggering ignition: $e');
      rethrow;
    }
  }

  Future<void> setValveAngle(int angle) async {
    try {
      await _ref.child('valve').child('angle').set(angle);
    } catch (e) {
      print('Error setting valve angle: $e');
      rethrow;
    }
  }

  Future<bool> getIsFlame() async {
    try {
      final snapshot = await _ref.child('flame').child('is_flame').get();
      if (snapshot.exists) {
        return snapshot.value as bool? ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Stream<bool> listenToIsFlame() {
    return _ref.child('flame').child('is_flame').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  // ============ Safety Sensor Methods ============

  Stream<bool> listenToSmokeSensor() {
    return _ref.child('smoke').child('is_fire').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  Stream<bool> listenToGasSensor() {
    // Hardcoded to false as per your original file
    return Stream.value(false);
  }

  Stream<bool> listenToCOSensor() {
    return _ref.child('CO').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  // ============ Flame Control Methods ============

  Future<void> setFlameLevel(String level) async {
    try {
      int angle;
      switch (level.toUpperCase()) {
        case 'OFF':
          angle = 0;
          break;
        case 'LOW':
          angle = 30;
          break;
        case 'MEDIUM':
          angle = 60;
          break;
        case 'HIGH':
          angle = 90;
          break;
        default:
          angle = 0;
      }
      await setValveAngle(angle);
      await _ref.child('flame').child('level').set(level);
    } catch (e) {
      print('Error setting flame level: $e');
      rethrow;
    }
  }

  Future<String> getFlameStatus() async {
    try {
      final snapshot = await _ref.child('flame').child('level').get();
      if (snapshot.exists) {
        return snapshot.value as String? ?? 'OFF';
      }
      return 'OFF';
    } catch (e) {
      return 'OFF';
    }
  }

  Stream<String> getFlameStatusStream() {
    return _ref.child('flame').child('level').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String? ?? 'OFF';
      }
      return 'OFF';
    });
  }
}
