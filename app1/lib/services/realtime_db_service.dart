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
    _dbRef ??= FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://chefbot-smartcooker-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref();
    return _dbRef!;
  }

  Future<Map<String, String>> getCameraConfig() async {
    print("RealtimeDBService: getCameraConfig called");

    // Return hardcoded values from the user's database
    // Based on: https://chefbot-smartcooker-default-rtdb.asia-southeast1.firebasedatabase.app/
    // Data: stream_url: "http://10.171.122.237:81/stream", capture_url: "http://10.171.122.237/capture"

    final result = {
      'stream_url': 'http://10.171.122.237:81/stream',
      'capture_url': 'http://10.171.122.237/capture',
    };

    print("RealtimeDBService: Returning hardcoded config: $result");
    return result;
  }

  // ============ Gas Cooker Control Methods ============

  /// Set ignition to true, then automatically set to false after 5 seconds
  Future<void> triggerIgnition() async {
    try {
      await _ref.child('ignition').set(true);
      print('RealtimeDBService: Set ignition to true');

      // Automatically set back to false after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      await _ref.child('ignition').set(false);
      print('RealtimeDBService: Set ignition to false after 5 seconds');
    } catch (e) {
      print('Error triggering ignition: $e');
      rethrow;
    }
  }

  /// Set valve angle (0, 30, 60, or 90) - this controls the flame level
  Future<void> setValveAngle(int angle) async {
    try {
      await _ref.child('valve').child('angle').set(angle);
      print('RealtimeDBService: Set valve/angle to $angle');
    } catch (e) {
      print('Error setting valve angle: $e');
      rethrow;
    }
  }

  /// Get current is_flame status from flame/is_flame
  Future<bool> getIsFlame() async {
    try {
      final snapshot = await _ref.child('flame').child('is_flame').get();
      if (snapshot.exists) {
        return snapshot.value as bool? ?? false;
      }
      return false;
    } catch (e) {
      print('Error getting flame/is_flame: $e');
      return false;
    }
  }

  /// Listen to is_flame changes at flame/is_flame
  Stream<bool> listenToIsFlame() {
    return _ref.child('flame').child('is_flame').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  // ============ Safety Sensor Methods ============

  /// Listen to smoke sensor changes at smoke/is_fire
  Stream<bool> listenToSmokeSensor() {
    return _ref.child('smoke').child('is_fire').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  /// Listen to gas sensor changes at gas/is_leak (hardcoded to false)
  Stream<bool> listenToGasSensor() {
    // Hardcoded to always return false
    return Stream.value(false);
  }

  /// Listen to CO sensor changes at root level CO
  Stream<bool> listenToCOSensor() {
    return _ref.child('CO').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  /// Get current safety sensor values
  Future<Map<String, bool>> getSafetySensors() async {
    try {
      final snapshot = await _ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final smokeData = data['smoke'] as Map<dynamic, dynamic>?;
        final gasData = data['gas'] as Map<dynamic, dynamic>?;
        return {
          'smoke': smokeData?['is_fire'] as bool? ?? false,
          'gas': gasData?['is_leak'] as bool? ?? false,
          'co': data['CO'] as bool? ?? false,
        };
      }
      return {'smoke': false, 'gas': false, 'co': false};
    } catch (e) {
      print('Error getting safety sensors: $e');
      return {'smoke': false, 'gas': false, 'co': false};
    }
  }
}
