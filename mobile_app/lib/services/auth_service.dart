import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart'; // you might need to add this dep

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Sign in with email & password
  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _storeJwt(cred.user?.uid);
    return cred;
  }

  // Sign up
  Future<UserCredential> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // Create user doc with role (default: student)
    await _db.collection('users').doc(cred.user?.uid).set({
      'email': email,
      'role': 'student',
    });
    await _storeJwt(cred.user?.uid);
    return cred;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: 'jwt');
  }

  // Retrieve JWT from backend (placeholder)
  Future<void> _storeJwt(String? uid) async {
    if (uid == null) return;
    // In a real app you would call your backend to get a signed JWT.
    // Here we just create a dummy token payload for illustration.
    final dummyPayload = {
      'sub': uid,
      'role': await _getUserRole(uid),
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    };
    // Encode payload as base64 (not a real signature). This is just for demo.
    final token = '${base64Url.encode(const Utf8Encoder().convert('header'))}.${base64Url.encode(const Utf8Encoder().convert(dummyPayload.toString()))}.signature';
    await _secureStorage.write(key: 'jwt', value: token);
  }

  Future<String> _getUserRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['role'] ?? 'student';
  }

  // Get stored JWT
  Future<String?> getJwt() async => await _secureStorage.read(key: 'jwt');

  // Decode JWT (no verification)
  Map<String, dynamic>? decodeJwt(String token) {
    try {
      return Jwt.parseJwt(token);
    } catch (_) {
      return null;
    }
  }
}
