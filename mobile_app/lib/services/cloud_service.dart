import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'local_db_service.dart';

class CloudService {
  // Singleton pattern
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth => isFirebaseAvailable ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestore => isFirebaseAvailable ? FirebaseFirestore.instance : null;
  FirebaseStorage? get _storage => isFirebaseAvailable ? FirebaseStorage.instance : null;
  FirebaseAnalytics? get _analytics => isFirebaseAvailable ? FirebaseAnalytics.instance : null;

  // Simple sign‑in with email/password – can be expanded later.
  Future<UserCredential> signIn(String email, String password) async {
    if (!isFirebaseAvailable) {
      throw StateError('Firebase is not initialized.');
    }
    return await _auth!.signInWithEmailAndPassword(email: email, password: password);
  }

  // Upload a base64 image to Firebase Storage and return the public URL.
  Future<String> _uploadImage(String userId, String base64Image, DateTime timestamp) async {
    if (!isFirebaseAvailable) {
      throw StateError('Firebase is not initialized.');
    }
    final bytes = base64Decode(base64Image);
    final ref = _storage!.ref().child('attendance_images').child(userId).child('${timestamp.millisecondsSinceEpoch}.png');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    return await ref.getDownloadURL();
  }

  // Primary method used by the app to record an attendance.
  // It uploads the image, stores a Firestore document, logs analytics and returns a map similar to the API response.
  Future<Map<String, dynamic>> checkIn(String userId, String base64Image, {double? latitude, double? longitude}) async {
    if (!isFirebaseAvailable) {
      return {'message': 'Firebase not initialized. Attendance not recorded in cloud.'};
    }
    final timestamp = DateTime.now();
    // Upload image first.
    final imageUrl = await _uploadImage(userId, base64Image, timestamp);

    // Build Firestore document.
    final doc = {
      'user_id': userId,
      'image_url': imageUrl,
      'timestamp': timestamp.toUtc(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    await _firestore!.collection('attendances').add(doc);

    // Log analytics event.
    await _analytics!.logEvent(name: 'attendance_checkin', parameters: {
      'user_id': userId,
      'has_location': latitude != null && longitude != null,
    });

    return {'message': 'Attendance recorded in cloud'};
  }

  // Called when connectivity returns – pushes any locally stored records to Firestore.
  Future<void> syncPending() async {
    if (!isFirebaseAvailable) {
      debugPrint('Firebase is not initialized. Skipping cloud sync.');
      return;
    }
    final pending = await LocalDbService().getPendingAttendances();
    for (final att in pending) {
      try {
        // Use the same logic as checkIn but with the stored base64 image.
        final imageUrl = await _uploadImage(att.userId, att.base64Image, att.timestamp);
        final doc = {
          'user_id': att.userId,
          'image_url': imageUrl,
          'timestamp': att.timestamp.toUtc(),
          if (att.latitude != null) 'latitude': att.latitude,
          if (att.longitude != null) 'longitude': att.longitude,
        };
        await _firestore!.collection('attendances').add(doc);
        // Mark as synced locally.
        if (att.id != null) {
          await LocalDbService().markAsSynced(att.id!);
        }
        // Optional analytics for each synced record.
        await _analytics!.logEvent(name: 'attendance_synced', parameters: {
          'user_id': att.userId,
        });
      } catch (e) {
        // If one fails we continue with others; they will be retried later.
        debugPrint('Failed to sync attendance id=${att.id}: $e');
      }
    }
  }
}
