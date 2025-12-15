import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CookingSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String flameLevel; // "Low", "Medium", "High"

  CookingSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.flameLevel,
  });

  factory CookingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CookingSession(
      id: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationSeconds: data['durationSeconds'] as int,
      flameLevel: data['flameLevel'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'flameLevel': flameLevel,
    };
  }

  String get formattedDuration {
    final duration = Duration(seconds: durationSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(startTime);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(startTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(startTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${startTime.day}/${startTime.month}/${startTime.year}';
    }
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

  /// Save a cooking session to Firestore
  Future<void> saveCookingSession({
    required DateTime startTime,
    required DateTime endTime,
    required int durationSeconds,
    required String flameLevel,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cooking_history')
          .add({
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
            'durationSeconds': durationSeconds,
            'flameLevel': flameLevel,
          });
      print('Cooking session saved successfully');
    } catch (e) {
      print('Error saving cooking session: $e');
      rethrow;
    }
  }

  /// Get last N cooking sessions
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
      print('Error fetching cooking history: $e');
      return [];
    }
  }

  /// Delete a specific session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cooking_history')
          .doc(sessionId)
          .delete();
      print('Session deleted successfully');
    } catch (e) {
      print('Error deleting session: $e');
      rethrow;
    }
  }

  /// Clear all history
  Future<void> clearAllHistory() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('cooking_history')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      print('All history cleared successfully');
    } catch (e) {
      print('Error clearing history: $e');
      rethrow;
    }
  }
}
