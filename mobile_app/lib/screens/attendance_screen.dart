import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../theme/tesla_theme.dart';
import 'camera_screen.dart';
import 'qr_scanner_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  String _message = 'Ready to scan. Please look at the camera.';
  IconData _icon = Icons.face_outlined;
  Color _iconColor = TeslaTheme.primary;
  double? _manualLatitude;
  double? _manualLongitude;

  bool get _hasManualLocation =>
      _manualLatitude != null && _manualLongitude != null;

  @override
  void initState() {
    super.initState();
    ConnectivityService.init();
  }

  Future<void> _checkIn(String base64Image) async {
    setState(() {
      _isLoading = true;
      _message = _hasManualLocation
          ? 'Verifying face with manual location...'
          : 'Verifying face and geo-fence...';
      _icon = Icons.auto_awesome;
      _iconColor = TeslaTheme.onSurface;
    });

    double? lat;
    double? lng;

    if (_hasManualLocation) {
      lat = _manualLatitude;
      lng = _manualLongitude;
    } else {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled. Please enable GPS.');
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception(
            'Location permissions are permanently denied, we cannot request permissions.',
          );
        }

        final position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        setState(() {
          _message = 'GPS Error: $e';
          _icon = Icons.location_off_outlined;
          _iconColor = TeslaTheme.error;
          _isLoading = false;
        });
        return;
      }
    }

    try {
      final response =
          await ApiService.checkIn(base64Image, latitude: lat, longitude: lng);
      setState(() {
        _message = 'Success: ${response['message']}';
        _icon = Icons.verified_outlined;
        _iconColor = const Color(0xFF4ADE80);
      });
    } catch (e) {
      final err = e.toString().toLowerCase();
      final faceNotRecognized = err.contains('face not recognized') ||
          err.contains('face not found') ||
          err.contains('unknown face') ||
          (err.contains('face') && err.contains('not recognized')) ||
          (err.contains('face') && err.contains('not found'));

      if (faceNotRecognized) {
        setState(() {
          _message = 'Face not recognized. Please scan QR code.';
          _icon = Icons.qr_code_scanner_outlined;
          _iconColor = TeslaTheme.primary;
        });

        if (!mounted) return;
        final qrResult = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
        );

        if (!mounted) return;

        if (qrResult == null) {
          setState(() {
            _message = 'QR scan cancelled';
            _icon = Icons.error_outline;
            _iconColor = TeslaTheme.error;
          });
          return;
        }

        try {
          final qrResponse = await ApiService.submitAttendanceViaQr(
            qrResult,
            latitude: lat,
            longitude: lng,
          );
          setState(() {
            _message = 'Success: ${qrResponse['message']}';
            _icon = Icons.verified_outlined;
            _iconColor = const Color(0xFF4ADE80);
          });
        } catch (qrError) {
          setState(() {
            _message = qrError.toString().replaceAll('Exception:', '');
            _icon = Icons.error_outline;
            _iconColor = TeslaTheme.error;
          });
        }
      } else {
        setState(() {
          _message = e.toString().replaceAll('Exception:', '');
          _icon = Icons.error_outline;
          _iconColor = TeslaTheme.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(onImageCaptured: _checkIn),
      ),
    );
  }

  void _clearManualLocation() {
    setState(() {
      _manualLatitude = null;
      _manualLongitude = null;
      _message = 'Manual GPS cleared. Device GPS will be used.';
      _icon = Icons.my_location_outlined;
      _iconColor = TeslaTheme.primary;
    });
  }

  void _openManualLocationDialog() {
    final latitudeController = TextEditingController(
      text: _manualLatitude?.toString() ?? '',
    );
    final longitudeController = TextEditingController(
      text: _manualLongitude?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TeslaTheme.surfaceHigh,
        title: const Text('Manual GPS Location', style: TextStyle(color: TeslaTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeslaTextField(
              controller: latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              labelText: 'Latitude',
              prefixIcon: Icons.north,
            ),
            const SizedBox(height: 12),
            TeslaTextField(
              controller: longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              labelText: 'Longitude',
              prefixIcon: Icons.east,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: TeslaTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              final latitude = double.tryParse(latitudeController.text.trim());
              final longitude =
                  double.tryParse(longitudeController.text.trim());

              if (latitude == null ||
                  longitude == null ||
                  latitude < -90 ||
                  latitude > 90 ||
                  longitude < -180 ||
                  longitude > 180) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter valid latitude (-90 to 90) and longitude (-180 to 180).',
                    ),
                  ),
                );
                return;
              }

              setState(() {
                _manualLatitude = latitude;
                _manualLongitude = longitude;
                _message = 'Manual GPS set. Start scan when ready.';
                _icon = Icons.edit_location_alt_outlined;
                _iconColor = TeslaTheme.primary;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save', style: TextStyle(color: TeslaTheme.primary)),
          ),
        ],
      ),
    ).whenComplete(() {
      latitudeController.dispose();
      longitudeController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mark Attendance', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const _ScannerPreview(),
              const SizedBox(height: 40),
              
              TeslaCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, color: _iconColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _message,
                        style: const TextStyle(
                          color: TeslaTheme.onSurface,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TeslaCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _hasManualLocation
                          ? Icons.edit_location_alt_outlined
                          : Icons.my_location_outlined,
                      color: _hasManualLocation ? TeslaTheme.primary : TeslaTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasManualLocation
                            ? 'Manual GPS: ${_manualLatitude!.toStringAsFixed(5)}, ${_manualLongitude!.toStringAsFixed(5)}'
                            : 'Using device GPS for attendance',
                        style: const TextStyle(
                          color: TeslaTheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Change GPS',
                      onPressed: _isLoading ? null : _openManualLocationDialog,
                      icon: const Icon(Icons.edit_outlined, color: TeslaTheme.onSurfaceVariant),
                    ),
                    if (_hasManualLocation)
                      IconButton(
                        tooltip: 'Clear manual GPS',
                        onPressed: _isLoading ? null : _clearManualLocation,
                        icon: const Icon(Icons.close, color: TeslaTheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              TeslaButton(
                onPressed: _isLoading ? null : () => _openCamera(context),
                isLoading: _isLoading,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Start AI Scan'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TeslaButton(
                onPressed: _isLoading ? null : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QrScannerScreen(),
                  ),
                ),
                isSecondary: true,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Use QR fallback'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerPreview extends StatefulWidget {
  const _ScannerPreview();

  @override
  State<_ScannerPreview> createState() => _ScannerPreviewState();
}

class _ScannerPreviewState extends State<_ScannerPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TeslaTheme.primary.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: TeslaTheme.primary.withValues(alpha: 0.05),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeslaTheme.surfaceHigh,
                border: Border.all(color: TeslaTheme.outlineVariant),
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: TeslaTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural,
                          color: TeslaTheme.onSurfaceVariant,
                          size: 64,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Positioned(
                          left: 0,
                          right: 0,
                          top: _controller.value * 250,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  TeslaTheme.primary.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: TeslaTheme.primary.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
