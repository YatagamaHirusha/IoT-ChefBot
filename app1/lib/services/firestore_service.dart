import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save user data to Firestore
  Future<void> saveUserData({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'hasCooker': false,
      });
      print('User data saved to Firestore');
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  // Save cooker data linked to user
  Future<void> saveCookerData({
    required String uid,
    required String macAddress,
    required String cookerName,
  }) async {
    try {
      // Create a cooker document with MAC address as ID
      await _firestore.collection('cookers').doc(macAddress).set({
        'macAddress': macAddress,
        'userId': uid,
        'cookerName': cookerName,
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Update user to indicate they have a cooker
      await _firestore.collection('users').doc(uid).update({
        'hasCooker': true,
        'cookerMacAddress': macAddress,
        'cookerRegisteredAt': FieldValue.serverTimestamp(),
      });

      print('Cooker data saved to Firestore');
    } catch (e) {
      print('Error saving cooker data: $e');
      rethrow;
    }
  }

  // Check if user has a cooker registered
  Future<bool> userHasCooker(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        return userData?['hasCooker'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking if user has cooker: $e');
      return false;
    }
  }

  // Get user's cooker MAC address
  Future<String?> getUserCookerMacAddress(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        return userData?['cookerMacAddress'];
      }
      return null;
    } catch (e) {
      print('Error getting cooker MAC address: $e');
      return null;
    }
  }

  // Get cooker details by MAC address
  Future<Map<String, dynamic>?> getCookerDetails(String macAddress) async {
    try {
      DocumentSnapshot cookerDoc = await _firestore
          .collection('cookers')
          .doc(macAddress)
          .get();

      if (cookerDoc.exists) {
        return cookerDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting cooker details: $e');
      return null;
    }
  }

  // Get user details
  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }
}
