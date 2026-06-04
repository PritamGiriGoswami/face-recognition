import re

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Add imports
imports = """import 'dart:io' show SocketException, File;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'face_match_mobile.dart';
"""
code = code.replace("import 'dart:io' show SocketException;", imports)

# Replace register
register_old = r"  static Future<Map<String, dynamic>> register\(.*?\}\n"
register_new = """  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String base64Image, {
    String? className,
    String? department,
  }) async {
    try {
      final String base64Str = base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_register.jpg');
      await file.writeAsBytes(bytes);
      
      final embeddings = await FaceMatchService.getEmbeddings(file);
      if (embeddings == null) throw Exception('No face detected in the image.');

      final docRef = await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'email': email,
        'class_name': className ?? '',
        'department': department ?? '',
        'embeddings': embeddings,
        'registered_at': FieldValue.serverTimestamp(),
      });
      return {'name': name, 'id': docRef.id, 'message': 'Registered successfully in Firebase.'};
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }
"""
code = re.sub(r"  static Future<Map<String, dynamic>> register\(.*?throw Exception\(_errorMessage\(response, 'Registration failed'\)\);\n    }\n  }", register_new, code, flags=re.DOTALL)

# Replace checkIn
checkin_old = r"  static Future<Map<String, dynamic>> checkIn\(.*?\}\n"
checkin_new = """  static Future<Map<String, dynamic>> checkIn(
    String base64Image, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final String base64Str = base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_checkin.jpg');
      await file.writeAsBytes(bytes);
      
      final liveEmbeddings = await FaceMatchService.getEmbeddings(file);
      if (liveEmbeddings == null) throw Exception('No face detected in the image.');

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      if (usersSnapshot.docs.isEmpty) throw Exception('No registered users found in database.');

      double bestScore = 0.0;
      String? bestUserId;
      String? bestUserName;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data['embeddings'] != null) {
          List<double> refEmbeddings = List<double>.from(data['embeddings']);
          double score = FaceMatchService.compareFaces(refEmbeddings, liveEmbeddings);
          if (score > bestScore) {
            bestScore = score;
            bestUserId = doc.id;
            bestUserName = data['name'];
          }
        }
      }

      // Threshold for MobileFaceNet is typically around 0.8
      if (bestScore > 0.8 && bestUserId != null) {
        // Record attendance
        await FirebaseFirestore.instance.collection('attendances').add({
          'user_id': bestUserId,
          'name': bestUserName,
          'timestamp': FieldValue.serverTimestamp(),
          'latitude': latitude,
          'longitude': longitude,
          'confidence': bestScore,
        });
        return {'message': 'Check-in successful', 'user': bestUserName, 'confidence': bestScore};
      } else {
        throw Exception('Face not recognized. Best match score: ${bestScore.toStringAsFixed(2)}');
      }
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }
"""
code = re.sub(r"  static Future<Map<String, dynamic>> checkIn\(.*?throw Exception\(_errorMessage\(response, 'Check-in failed'\)\);\n    }\n  }", checkin_new, code, flags=re.DOTALL)

with open('lib/services/api_service.dart', 'w', encoding='utf-8') as f:
    f.write(code)
