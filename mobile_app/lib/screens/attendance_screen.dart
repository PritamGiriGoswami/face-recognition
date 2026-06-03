import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../theme/lumina.dart';
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
  Color _iconColor = Lumina.primary;
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
      _iconColor = Lumina.tertiary;
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
          _iconColor = Lumina.error;
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
          _iconColor = Lumina.secondary;
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
            _iconColor = Lumina.error;
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
            _iconColor = Lumina.error;
          });
        }
      } else {
        setState(() {
          _message = e.toString().replaceAll('Exception:', '');
          _icon = Icons.error_outline;
          _iconColor = Lumina.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EduTopBar(),
      extendBody: true,
      bottomNavigationBar: EduBottomNav(
        selectedIndex: 1,
        onSelected: (index) {
          if (index == 0) Navigator.pop(context);
          if (index == 1 && !_isLoading) _openCamera(context);
        },
      ),
      body: LuminaShell(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _ScannerPreview(),
            const SizedBox(height: 28),
            Text(
              _isLoading ? 'Scanning...' : 'Mark Attendance',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Lumina.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please look into the camera and keep steady.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Lumina.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 28),
            GlassCard(
              accent: _iconColor,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _iconColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: _iconColor, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _message,
                      style: const TextStyle(
                        color: Lumina.onSurface,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GlassCard(
              accent: _hasManualLocation ? Lumina.tertiary : Lumina.outline,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _hasManualLocation
                        ? Icons.edit_location_alt_outlined
                        : Icons.my_location_outlined,
                    color:
                        _hasManualLocation ? Lumina.tertiary : Lumina.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _hasManualLocation
                          ? 'Manual GPS: ${_manualLatitude!.toStringAsFixed(5)}, ${_manualLongitude!.toStringAsFixed(5)}'
                          : 'Using device GPS for attendance',
                      style: const TextStyle(
                        color: Lumina.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Change GPS',
                    onPressed: _isLoading ? null : _openManualLocationDialog,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (_hasManualLocation)
                    IconButton(
                      tooltip: 'Clear manual GPS',
                      onPressed: _isLoading ? null : _clearManualLocation,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const CircularProgressIndicator(color: Lumina.tertiary)
            else
              FilledButton.icon(
                onPressed: () => _openCamera(context),
                icon: const Icon(Icons.face_outlined),
                label: const Text('Start AI Scan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Lumina.primary,
                  foregroundColor: Lumina.onPrimary,
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      ),
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Use QR fallback'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
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
      _iconColor = Lumina.primary;
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
        title: const Text('Manual GPS Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: '22.57260',
                prefixIcon: Icon(Icons.north),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: '88.36390',
                prefixIcon: Icon(Icons.east),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
                _iconColor = Lumina.tertiary;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      latitudeController.dispose();
      longitudeController.dispose();
    });
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
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Lumina.primary.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Lumina.primary.withValues(alpha: 0.22),
                  blurRadius: 36,
                ),
              ],
            ),
          ),
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lumina.surfaceHighest,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _FaceGridPainter()),
                  Center(
                    child: Container(
                      width: 160,
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Lumina.tertiary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural,
                        color: Lumina.primary,
                        size: 86,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Positioned(
                        left: 0,
                        right: 0,
                        top: _controller.value * 290,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Lumina.tertiary.withValues(alpha: 0.32),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 22,
            left: 22,
            child: _Bracket(top: true, left: true),
          ),
          const Positioned(
            top: 22,
            right: 22,
            child: _Bracket(top: true, right: true),
          ),
          const Positioned(
            bottom: 22,
            left: 22,
            child: _Bracket(bottom: true, left: true),
          ),
          const Positioned(
            bottom: 22,
            right: 22,
            child: _Bracket(bottom: true, right: true),
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  const _Bracket({
    this.top = false,
    this.right = false,
    this.bottom = false,
    this.left = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: Lumina.tertiary, width: 3)
              : BorderSide.none,
          right: right
              ? const BorderSide(color: Lumina.tertiary, width: 3)
              : BorderSide.none,
          bottom: bottom
              ? const BorderSide(color: Lumina.tertiary, width: 3)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: Lumina.tertiary, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}

class _FaceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Lumina.tertiary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
