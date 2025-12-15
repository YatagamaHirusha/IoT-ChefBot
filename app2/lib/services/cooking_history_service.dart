import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyAlert {
  final String type; // 'gas', 'smoke', 'co'
  final DateTime timestamp;

  SafetyAlert({required this.type, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {'type': type, 'timestamp': Timestamp.fromDate(timestamp)};
  }

  factory SafetyAlert.fromMap(Map<String, dynamic> map) {
    return SafetyAlert(
      type: map['type'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get displayName {
    switch (type) {
      case 'gas':
        return 'Gas Leak';
      case 'smoke':
        return 'Smoke Detected';
      case 'co':
        return 'CO Detected';
      default:
        return type.toUpperCase();
    }
  }
}

class CookingSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String flameLevel;
  final List<SafetyAlert>? safetyAlerts;

  CookingSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.flameLevel,
    this.safetyAlerts,
  });

  factory CookingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    List<SafetyAlert>? alerts;
    if (data['safetyAlerts'] != null) {
      alerts = (data['safetyAlerts'] as List)
          .map((a) => SafetyAlert.fromMap(a))
          .toList();
    }
    return CookingSession(
      id: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationSeconds: data['durationSeconds'] as int,
      flameLevel: data['flameLevel'] as String,
      safetyAlerts: alerts,
    );
  }

  String get formattedDuration {
    final duration = Duration(seconds: durationSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    if (difference.inDays == 0) return 'Today ${_formatTime(startTime)}';
    if (difference.inDays == 1) return 'Yesterday ${_formatTime(startTime)}';
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class CookingHistoryService {
  static final CookingHistoryService _instance =
      CookingHistoryService._internal();

  factory CookingHistoryService() {
    return _instance;
  }

  CookingHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'anonymous';
  }

  Future<void> saveCookingSession({
    required DateTime startTime,
    required DateTime endTime,
    required int durationSeconds,
    required String flameLevel,
    List<SafetyAlert>? safetyAlerts,
  }) async {
    try {
      final data = {
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationSeconds': durationSeconds,
        'flameLevel': flameLevel,
      };

      if (safetyAlerts != null && safetyAlerts.isNotEmpty) {
        data['safetyAlerts'] = safetyAlerts.map((a) => a.toMap()).toList();
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cooking_history')
          .add(data);
    } catch (e) {
      print('Error saving cooking session: $e');
      rethrow;
    }
  }

  Future<List<CookingSession>> getCookingHistory({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cooking_history')
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CookingSession.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CookingSession>> getRecentSessions({int limit = 5}) async {
    return getCookingHistory(limit: limit);
  }

  Future<void> deleteSession(String sessionId) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('cooking_history')
        .doc(sessionId)
        .delete();
  }

  Future<void> clearAllHistory() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('cooking_history')
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }
}
