import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/attendance.dart';
import 'local_db_service.dart';

class ApiService {
  static String _customBaseUrl = '';

  static String get customBaseUrl => _customBaseUrl;

  static void setCustomBaseUrl(String url) {
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
    _customBaseUrl = url;
  }

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String base64Image, {
    String? className,
    String? department,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        if (className != null) 'class_name': className,
        if (department != null) 'department': department,
        'face_image_base64': base64Image,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Registration failed');
    }
  }

  static Future<Map<String, dynamic>> checkIn(
    String base64Image, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/check_in'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'face_image_base64': base64Image,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Check-in failed');
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
       final result = await checkIn(base64Image, latitude: latitude, longitude: longitude);
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
     final response = await http.post(
       Uri.parse('$baseUrl/check_in_qr'),
       headers: {'Content-Type': 'application/json'},
       body: jsonEncode({
         'user_id': userId,
         if (latitude != null) 'latitude': latitude,
         if (longitude != null) 'longitude': longitude,
       }),
     );
     if (response.statusCode == 200) {
       return jsonDecode(response.body);
     } else {
       throw Exception(jsonDecode(response.body)['detail'] ?? 'QR check-in failed');
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
    final response = await http.post(
      Uri.parse('$baseUrl/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
    }
  }

  static Future<void> adminLogout(String token) async {
    await http.post(
      Uri.parse('$baseUrl/admin/logout'),
      headers: _adminHeaders(token),
    );
  }

  static Future<Map<String, dynamic>> getAdminStats(
    String token, {
    Map<String, String>? filters,
  }) async {
    final response = await http.get(
      _apiUri('/admin/stats', filters),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load admin stats');
    }
  }

  static Future<List<dynamic>> getAttendance(
    String token, {
    Map<String, String>? filters,
  }) async {
    final response = await http.get(
      _apiUri('/attendance', filters),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  static Future<List<dynamic>> getUsers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
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
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _adminHeaders(token),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Update failed');
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
    return http.get(
      _apiUri('/reports/attendance.$format', filters),
      headers: _adminHeaders(token),
    );
  }

  static Future<void> deleteUser(String token, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Delete failed');
    }
  }

  static Future<Map<String, dynamic>> getSettings(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/settings'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to load settings');
    }
  }

  static Future<Map<String, dynamic>> updateSettings(
      String token, Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/settings'),
      headers: _adminHeaders(token),
      body: jsonEncode(settings),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Failed to update settings');
    }
  }

  static Future<Map<String, dynamic>> getStudentDashboard(String email) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard?email=${Uri.encodeComponent(email)}'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['detail'] ?? 'Failed to load dashboard');
    }
  }
  static Future<List<dynamic>> getClasses(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classes'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load classes');
    }
  }

  static Future<Map<String, dynamic>> createClass(String token, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/classes'),
      headers: _adminHeaders(token),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to create class');
    }
  }

  static Future<void> deleteClass(String token, int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/classes/$id'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to delete class');
    }
  }

  static Future<List<dynamic>> getDepartments(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/departments'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load departments');
    }
  }

  static Future<Map<String, dynamic>> createDepartment(String token, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/departments'),
      headers: _adminHeaders(token),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to create department');
    }
  }

  static Future<void> deleteDepartment(String token, int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/departments/$id'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to delete department');
    }
  }

  static Future<List<dynamic>> getDevices(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load devices');
    }
  }

  static Future<void> performDeviceAction(String token, String deviceId, String action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/devices/$deviceId/action'),
      headers: _adminHeaders(token),
      body: jsonEncode({'action': action}),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to perform device action');
    }
  }

  static Future<List<dynamic>> getAlerts(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/alerts'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load alerts');
    }
  }

  static Future<void> markAlertRead(String token, int alertId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/alerts/$alertId/read'),
      headers: _adminHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark alert as read');
    }
  }
}
