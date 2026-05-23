import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import 'camera_screen.dart';
import 'qr_scanner_screen.dart';
import 'dart:typed_data';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  String _message = "Ready to scan. Please look at the camera.";
  IconData _icon = Icons.face;
  Color _iconColor = Colors.deepPurple;

  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.init();
  }

  Future<void> _checkIn(String base64Image) async {
    setState(() {
      _isLoading = true;
      _message = "Verifying face & geo-fence...";
      _icon = Icons.sync;
      _iconColor = Colors.orange;
    });

    double? lat;
    double? lng;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      Position position = await Geolocator.getCurrentPosition();
      lat = position.latitude;
      lng = position.longitude;
    } catch (e) {
      setState(() {
        _message = "GPS Error: $e";
        _icon = Icons.location_off;
        _iconColor = Colors.red;
        _isLoading = false;
        _isGettingLocation = false;
      });
      return;
    }

    try {
      // Step 1: Try face recognition online
      final response =
          await ApiService.checkIn(base64Image, latitude: lat, longitude: lng);
      setState(() {
        _message = "Success: ${response['message']}";
        _icon = Icons.check_circle;
        _iconColor = Colors.green;
      });
    } catch (e) {
      // Check if it's a face not recognized error (404)
      if (e.toString().contains('Face not recognized') ||
          e.toString().contains('404')) {
        // Step 2: Try QR code
        setState(() {
          _message = "Face not recognized. Please scan QR code.";
          _icon = Icons.qr_code_scanner;
          _iconColor = Colors.blue;
        });

        // Launch QR scanner
        final qrResult = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => const QrScannerScreen(),
          ),
        );

        if (qrResult == null) {
          // User cancelled QR scan
          setState(() {
            _message = "QR scan cancelled";
            _icon = Icons.error;
            _iconColor = Colors.red;
          });
          return;
        }

        try {
          // Step 3: Check-in via QR
          final qrResponse = await ApiService.submitAttendanceViaQr(
            qrResult,
            latitude: lat,
            longitude: lng,
          );
          setState(() {
            _message = "Success: ${qrResponse['message']}";
            _icon = Icons.check_circle;
            _iconColor = Colors.green;
          });
        } catch (qrError) {
          setState(() {
            _message = qrError.toString().replaceAll('Exception:', '');
            _icon = Icons.error;
            _iconColor = Colors.red;
          });
        }
      } else {
        // Other error (geo-fence, anti-spoofing, etc.)
        setState(() {
          _message = e.toString().replaceAll('Exception:', '');
          _icon = Icons.error;
          _iconColor = Colors.red;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon, size: 100, color: _iconColor),
                const SizedBox(height: 24),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraScreen(
                          onImageCaptured: _checkIn,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Scan Face"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 32,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
