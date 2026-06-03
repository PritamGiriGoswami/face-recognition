import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/attendance.dart';
import 'local_db_service.dart';

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 12);
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
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(_configuredBaseUrl);
    }
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
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

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String base64Image, {
    String? className,
    String? department,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        if (className != null && className.trim().isNotEmpty)
          'class_name': className.trim(),
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
        'face_image_base64': base64Image,
      }),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Registration failed'));
    }
  }

  static Future<Map<String, dynamic>> checkIn(
    String base64Image, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await _send(http.post(
      Uri.parse('$baseUrl/check_in'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'face_image_base64': base64Image,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Check-in failed'));
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
      headers: {'Content-Type': 'application/json'},
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
    final response = await _send(http.get(
      _apiUri('/admin/stats', filters),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load admin stats'));
    }
  }

  static Future<List<dynamic>> getAttendance(
    String token, {
    Map<String, String>? filters,
  }) async {
    final response = await _send(http.get(
      _apiUri('/attendance', filters),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load attendance'));
    }
  }

  static Future<List<dynamic>> getUsers(String token) async {
    final response = await _send(http.get(
      Uri.parse('$baseUrl/users'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Failed to load users'));
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    String token,
    int userId,
    String name,
    String email, {
    String? className,
    String? department,
    bool? isActive,
  }) async {
    final body = {
      'name': name,
      'email': email,
      if (className != null) 'class_name': className,
      if (department != null) 'department': department,
      if (isActive != null) 'is_active': isActive,
    };
    final response = await _send(http.patch(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _adminHeaders(token),
      body: jsonEncode(body),
    ));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_errorMessage(response, 'Update failed'));
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

  static Future<void> deleteUser(String token, int userId) async {
    final response = await _send(http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _adminHeaders(token),
    ));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Delete failed'));
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
