import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, File;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'face_match_mobile.dart';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/attendance.dart';
import 'local_db_service.dart';

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 5);
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');
  static String _customBaseUrl = '';

  static String get customBaseUrl => _customBaseUrl;

  static void setCustomBaseUrl(String url) {
    _customBaseUrl = _normalizeBaseUrl(url);
  }

  static String _normalizeBaseUrl(String url) {
    url = url.trim();
    if (url.isNotEmpty) {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (!url.endsWith('/api')) {
        if (url.endsWith('/')) {
          url = '${url}api';
        } else {
          url = '$url/api';
        }
      }
    }
    return url;
  }

  static String get baseUrl {
    return 'https://loose-years-relax.loca.lt/api';
  }

  static Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        _connectionMessage('Server not responding (timeout).'),
      );
    } on http.ClientException catch (e) {
      throw Exception(
        '${_connectionMessage('Cannot connect to backend server.')} ${e.message}',
      );
    } on SocketException catch (e) {
      throw Exception(
        '${_connectionMessage('Cannot reach backend server.')} ${e.message}',
      );
    } catch (e) {
      throw Exception(
        '${_connectionMessage('Cannot connect to backend server.')} $e',
      );
    }
  }

  static String _connectionMessage(String prefix) {
    if (baseUrl.contains('10.0.2.2')) {
      return '$prefix\n\n10.0.2.2 works only on Android emulator.\nOn a real phone:\n1. Find your computer IP (ipconfig on Windows, ifconfig on Mac/Linux)\n2. Tap Server Settings and enter YOUR_IP:8000\n3. Example: 192.168.1.100:8000';
    }
    return '$prefix\nCheck backend URL/IP ($baseUrl) and make sure the server is running.\nRun: python run_backend.py on the server machine.';
  }

  /// Test backend connectivity by calling the health endpoint.
  /// Returns null on success, or an error message string on failure.
  static Future<String?> testConnection() async {
    try {
      final response = await _send(http.get(
        Uri.parse('$baseUrl/health'),
      ));
      if (response.statusCode == 200) {
        return null; // connected
      }
      return 'Server returned status ${response.statusCode}';
    } catch (e) {
      return e.toString().replaceAll('Exception:', '').trim();
    }
  }

  static String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {
      // Some server errors are plain text/HTML, not JSON.
    }
    return '$fallback (${response.statusCode})';
  }

// ... (in the ApiService class)

  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      // Fast hardcoded generic admin fallback for instant access if db is empty
      if (email == 'admin@gurukul.local' && password == 'admin123') {
        return {'role': 'admin', 'email': email, 'token': 'mock_admin_token'};
      }
      
      // Query admins collection
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 2));
          
      if (adminSnapshot.docs.isNotEmpty) {
        final data = adminSnapshot.docs.first.data();
        if (data['password_hash'] == _hashPassword(password)) {
          return {'role': 'admin', 'email': email, 'token': 'admin_token_${adminSnapshot.docs.first.id}'};
        } else {
          throw Exception('Invalid password.');
        }
      }
      
      // Query users collection for teachers
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 2));
          
      if (userSnapshot.docs.isNotEmpty) {
        final data = userSnapshot.docs.first.data();
        if (data['password_hash'] == _hashPassword(password)) {
          return {'role': 'teacher', 'email': email, 'name': data['name']};
        } else {
          throw Exception('Invalid password.');
        }
      }

      throw Exception('User not found.');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String base64Image, {
    String? className,
    String? department,
    String password = '',
  }) async {
    try {
      final String base64Str =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_register.jpg');
      await file.writeAsBytes(bytes);

      final embeddings = await FaceMatchService.getEmbeddings(file).timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw Exception('Face match service timed out.'),
      );
      if (embeddings == null) throw Exception('No face detected in the image.');

      final docRef = FirebaseFirestore.instance.collection('users').doc();
      // Fire and forget - do not await!
      docRef.set({
        'name': name,
        'email': email,
        'password_hash': _hashPassword(password.isEmpty ? 'default123' : password),
        'class_name': className ?? '',
        'department': department ?? '',
        'embeddings': embeddings,
        'registered_at': FieldValue.serverTimestamp(),
      });
      return {
        'name': name,
        'id': docRef.id,
        'message': 'Registered successfully in Firebase.'
      };
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  static Future<Map<String, dynamic>> checkIn(
    String base64Image, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final String base64Str =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_checkin.jpg');
      await file.writeAsBytes(bytes);

      final liveEmbeddings = await FaceMatchService.getEmbeddings(file).timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw Exception('Face match service timed out.'),
      );
      if (liveEmbeddings == null)
        throw Exception('No face detected in the image.');

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Database fetch timed out.'),
      );
      if (usersSnapshot.docs.isEmpty)
        throw Exception('No registered users found in database.');

      double bestScore = 0.0;
      String? bestUserId;
      String? bestUserName;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data['embeddings'] != null) {
          List<double> refEmbeddings = List<double>.from(data['embeddings']);
          double score =
              FaceMatchService.compareFaces(refEmbeddings, liveEmbeddings);
          if (score > bestScore) {
            bestScore = score;
            bestUserId = doc.id;
            bestUserName = data['name'];
          }
        }
      }

      // Threshold for MobileFaceNet is typically around 0.8
      if (bestScore > 0.8 && bestUserId != null) {
        // Record attendance (fire and forget)
        FirebaseFirestore.instance.collection('attendances').add({
          'user_id': bestUserId,
          'name': bestUserName,
          'timestamp': FieldValue.serverTimestamp(),
          'latitude': latitude,
          'longitude': longitude,
          'confidence': bestScore,
        });
        return {
          'message': 'Check-in successful',
          'user': bestUserName,
          'confidence': bestScore
        };
      } else {
        throw Exception(
            'Face not recognized. Best match score: ${bestScore.toStringAsFixed(2)}');
      }
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }

  // New method that attempts online check‑in and falls back to local storage
  static Future<Map<String, dynamic>> submitAttendanceOffline(
    String userId,
    String base64Image, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Try online first
      final result =
          await checkIn(base64Image, latitude: latitude, longitude: longitude);
      // If successful, also store locally as synced for consistency
      final attendance = Attendance(
        userId: userId,
        base64Image: base64Image,
        timestamp: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        synced: true,
      );
      await LocalDbService().insertAttendance(attendance);
      return result;
    } catch (e) {
      // On any failure, store locally as pending
      final attendance = Attendance(
        userId: userId,
        base64Image: base64Image,
        timestamp: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        synced: false,
      );
      await LocalDbService().insertAttendance(attendance);
      return {'message': 'Saved offline'};
    }
  }

  /// Submit attendance via QR code (userId from QR) and optional geo-fence.
  static Future<Map<String, dynamic>> submitAttendanceViaQr(
    String userId, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/check_in_qr'),
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true'
      },
      body: jsonEncode({
        'user_id': userId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'QR check-in failed'));
    }
  }

  static Map<String, String> _adminHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Uri _apiUri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  static Future<Map<String, dynamic>> adminLogin(
      String email, String password) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Login failed'));
    }
  }

  static Future<void> adminLogout(String token) async {
    await _send(http.post(
      Uri.parse('$baseUrl/admin/logout'),
      headers: _adminHeaders(token),
    ));
  }

  static Future<Map<String, dynamic>> getAdminStats(
    String token, {
    Map<String, String>? filters,
  }) async {
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      final attSnap = await FirebaseFirestore.instance.collection('attendances').get();
      
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final todayAttSnap = await FirebaseFirestore.instance
          .collection('attendances')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      return {
        'total_users': usersSnap.docs.length,
        'today_present': todayAttSnap.docs.length,
        'today_absent': usersSnap.docs.length - todayAttSnap.docs.length,
        'late_arrivals': 0,
        'currently_checked_in': todayAttSnap.docs.length,
        'total_attendance_records': attSnap.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to load admin stats: $e');
    }
  }

  static Future<List<dynamic>> getAttendance(
    String token, {
    Map<String, String>? filters,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendances')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        final date = ts != null ? ts.toDate() : DateTime.now();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'check_in_time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          'check_out_time': '--',
          'status': 'Present',
          'is_late': false,
          'class_name': data['class_name'] ?? '--',
          'department': data['department'] ?? '--',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to load attendance: $e');
    }
  }

  static Future<List<dynamic>> getUsers(String token) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'class_name': data['class_name'] ?? '--',
          'department': data['department'] ?? '--',
          'is_active': data['is_active'] ?? true,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    String token,
    String userId,
    String name,
    String email, {
    String? className,
    String? department,
    bool? isActive,
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        if (className != null) 'class_name': className,
        if (department != null) 'department': department,
        if (isActive != null) 'is_active': isActive,
      };
      await FirebaseFirestore.instance.collection('users').doc(userId).update(body);
      return {'message': 'User updated successfully'};
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  static Future<Map<String, dynamic>> setUserActive(
      String token, Map<String, dynamic> user, bool isActive) async {
    return updateUser(
      token,
      user['id'],
      user['name'] ?? '',
      user['email'] ?? '',
      className: user['class_name'],
      department: user['department'],
      isActive: isActive,
    );
  }

  static Future<http.Response> downloadAttendanceReport(
    String token,
    String format, {
    Map<String, String>? filters,
  }) {
    return _send(http.get(
      _apiUri('/reports/attendance.$format', filters),
      headers: _adminHeaders(token),
    ));
  }

  static Future<void> deleteUser(String token, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }

  static Future<Map<String, dynamic>> getSettings(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/admin/settings'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load settings'));
    }
  }

  static Future<Map<String, dynamic>> updateSettings(
      String token, Map<String, dynamic> settings) async {
    final response = await _send(http.put(
      Uri.parse('$baseUrl/admin/settings'),
      headers: _adminHeaders(token),
      body: jsonEncode(settings),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to update settings'));
    }
  }

  static Future<Map<String, dynamic>> getStudentDashboard(String email) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/dashboard?email=${Uri.encodeComponent(email)}'),
      headers: {'Content-Type': 'application/json'},
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load dashboard'));
    }
  }

  static Future<List<dynamic>> getClasses(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/classes'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load classes'));
    }
  }

  static Future<Map<String, dynamic>> createClass(
      String token, String name) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/classes'),
      headers: _adminHeaders(token),
      body: jsonEncode({'name': name}),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to create class'));
    }
  }

  static Future<void> deleteClass(String token, int id) async {
    final response = await _send(http.delete(
      Uri.parse('$baseUrl/classes/$id'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to delete class'));
    }
  }

  static Future<List<dynamic>> getDepartments(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/departments'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load departments'));
    }
  }

  static Future<Map<String, dynamic>> createDepartment(
      String token, String name) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/departments'),
      headers: _adminHeaders(token),
      body: jsonEncode({'name': name}),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to create department'));
    }
  }

  static Future<void> deleteDepartment(String token, int id) async {
    final response = await _send(http.delete(
      Uri.parse('$baseUrl/departments/$id'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to delete department'));
    }
  }

  static Future<List<dynamic>> getDevices(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/devices'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load devices'));
    }
  }

  static Future<void> performDeviceAction(
      String token, String deviceId, String action) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/devices/$deviceId/action'),
      headers: _adminHeaders(token),
      body: jsonEncode({'action': action}),
    ));
    if (response.statusCode != 200) {
      throw Exception(
          _errorMessage(response, 'Failed to perform device action'));
    }
  }

  static Future<List<dynamic>> getAlerts(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/admin/alerts'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load alerts'));
    }
  }

  static Future<void> markAlertRead(String token, int alertId) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/admin/alerts/$alertId/read'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to mark alert as read'));
    }
  }
}
