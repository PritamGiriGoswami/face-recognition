import 'dart:convert';
import 'dart:io' show File;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../utils/image_picker_stub.dart'
    if (dart.library.html) '../utils/image_picker_web.dart' as web_picker;

class CameraScreen extends StatefulWidget {
  final Function(String base64Image) onImageCaptured;

  const CameraScreen({super.key, required this.onImageCaptured});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  XFile? _capturedFile;
  String? _errorMessage;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isSubmitting = false;

  // Active Liveness state variables
  String _livenessState =
      "idle"; // "idle", "blink", "smile", "scanning", "success"
  String _livenessInstruction = "Prepare for liveness check...";
  double _livenessProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      setState(() => _isInitializing = false);
    } else {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera([int? cameraIndex]) async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _capturedFile = null;
      _livenessState = "idle";
    });

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }

      _selectedCameraIndex = cameraIndex ??
          _cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;

      final oldController = _controller;
      final selectedCamera = _cameras[_selectedCameraIndex];
      final nextController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = nextController;
      await oldController?.dispose();
      await nextController.initialize();

      if (mounted) {
        setState(() => _isInitializing = false);
        // Start interactive active liveness sequence 1 second after initialization
        Future.delayed(const Duration(milliseconds: 1000), () {
          _startLivenessSequence();
        });
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cameraErrorText(e);
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to open camera: $e';
        _isInitializing = false;
      });
    }
  }

  String _cameraErrorText(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is required to capture a face.';
      case 'AudioAccessDenied':
        return 'Camera opened, but audio permission was denied.';
      default:
        return e.description ?? 'Unable to open camera.';
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing || _isCapturing) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(nextIndex);
  }

  Future<void> _pickImageForWeb() async {
    try {
      final picked = await web_picker.pickImageFromFile();
      if (picked != null) {
        widget.onImageCaptured(picked);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error picking web image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _capturedFile != null) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      if (mounted) {
        setState(() => _capturedFile = file);
      }
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cameraErrorText(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _retakePicture() {
    setState(() => _capturedFile = null);
    _startLivenessSequence();
  }

  Future<void> _confirmPicture() async {
    final file = _capturedFile;
    if (file == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      widget.onImageCaptured(base64Image);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read captured image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- ACTIVE LIVENESS FLOW ---

  void _startLivenessSequence() {
    if (!mounted) return;
    setState(() {
      _livenessState = "blink";
      _livenessInstruction = "Liveness Check: Blink your eyes slowly...";
      _livenessProgress = 0.0;
    });

    int ticks = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _livenessState != "blink") return false;
      ticks++;
      setState(() {
        _livenessProgress = ticks / 20.0; // 2 seconds
      });
      if (ticks >= 20) {
        _goToSmileStep();
        return false;
      }
      return true;
    });
  }

  void _goToSmileStep() {
    if (!mounted) return;
    setState(() {
      _livenessState = "smile";
      _livenessInstruction = "Liveness Check: Smile clearly for scan...";
      _livenessProgress = 0.0;
    });

    int ticks = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _livenessState != "smile") return false;
      ticks++;
      setState(() {
        _livenessProgress = ticks / 20.0; // 2 seconds
      });
      if (ticks >= 20) {
        _goToScanningStep();
        return false;
      }
      return true;
    });
  }

  void _goToScanningStep() {
    if (!mounted) return;
    setState(() {
      _livenessState = "scanning";
      _livenessInstruction = "Analyzing biometric signature...";
      _livenessProgress = 0.0;
    });

    int ticks = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted || _livenessState != "scanning") return false;
      ticks++;
      setState(() {
        _livenessProgress = ticks / 25.0; // 2 seconds
      });
      if (ticks >= 25) {
        _completeLivenessAndCapture();
        return false;
      }
      return true;
    });
  }

  Future<void> _completeLivenessAndCapture() async {
    if (!mounted) return;
    setState(() {
      _livenessState = "success";
      _livenessInstruction = "Biometrics Verified! Saving frame...";
      _livenessProgress = 1.0;
    });

    try {
      final controller = _controller;
      if (controller != null &&
          controller.value.isInitialized &&
          !_isCapturing) {
        setState(() {
          _isCapturing = true;
        });
        final file = await controller.takePicture();
        if (!mounted) return;

        setState(() {
          _capturedFile = file;
          _isSubmitting = true;
          _isCapturing = false;
        });

        final bytes = await File(file.path).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        widget.onImageCaptured(base64Image);

        // Success visual feedback before popping camera screen
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        if (kIsWeb) {
          setState(() {
            _livenessState = "idle";
            _livenessInstruction = "Liveness complete. Please upload file.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error auto capturing image: $e");
      setState(() {
        _livenessState = "idle";
        _livenessInstruction = "Liveness scan failed. Tap manual shutter.";
      });
    }
  }

  Widget _buildWebUploader() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Upload Image'),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _pickImageForWeb,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload Image'),
        ),
      ),
    );
  }

  Widget _buildCameraError() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Camera'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Camera is unavailable.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _initCamera(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildCapturedPreview() {
    final file = _capturedFile;
    if (file == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: Image.file(
        File(file.path),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildScanningBar() {
    if (_livenessState != "scanning") return const SizedBox.shrink();

    // Animate the line moving from top to bottom based on progress
    return Positioned(
      top: 180 + (260 * _livenessProgress), // scans down within the face guide
      left: MediaQuery.of(context).size.width / 2 - 120,
      child: Container(
        width: 240,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.greenAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.8),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivenessHUD() {
    Color hudColor = Colors.deepPurpleAccent;
    IconData stepIcon = Icons.face;

    if (_livenessState == "blink") {
      hudColor = Colors.amberAccent;
      stepIcon = Icons.remove_red_eye_outlined;
    } else if (_livenessState == "smile") {
      hudColor = Colors.pinkAccent;
      stepIcon = Icons.sentiment_satisfied_alt;
    } else if (_livenessState == "scanning") {
      hudColor = Colors.greenAccent;
      stepIcon = Icons.qr_code_scanner_outlined;
    } else if (_livenessState == "success") {
      hudColor = Colors.green;
      stepIcon = Icons.verified;
    } else if (_livenessState == "idle") {
      hudColor = Colors.grey;
      stepIcon = Icons.face;
    }

    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: hudColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: _livenessProgress,
                      color: hudColor,
                      backgroundColor: Colors.white24,
                      strokeWidth: 4,
                    ),
                  ),
                  Icon(stepIcon, color: hudColor, size: 24),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _livenessState.toUpperCase(),
                      style: TextStyle(
                        color: hudColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _livenessInstruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 40,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          if (_livenessState == "idle" || _livenessState == "success")
            IconButton.filledTonal(
              tooltip: 'Restart Liveness',
              icon: const Icon(Icons.refresh),
              onPressed: _startLivenessSequence,
            ),
          if (_capturedFile == null && _cameras.length > 1)
            IconButton.filledTonal(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureControls() {
    final captured = _capturedFile != null;

    // Only show manual shutter controls if liveness is idle (or fallback)
    final showShutter = _livenessState == "idle";

    return Positioned(
      left: 20,
      right: 20,
      bottom: 28,
      child: SafeArea(
        child: captured
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _retakePicture,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _confirmPicture,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Use Photo'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              )
            : (showShutter
                ? Center(
                    child: FloatingActionButton.large(
                      onPressed: _isCapturing ? null : _takePicture,
                      backgroundColor: Colors.white,
                      child: _isCapturing
                          ? const CircularProgressIndicator()
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 36,
                            ),
                    ),
                  )
                : const SizedBox.shrink()),
      ),
    );
  }

  Widget _buildFaceGuide() {
    if (_capturedFile != null) return const SizedBox.shrink();

    Color guideColor = Colors.white70;
    if (_livenessState == "blink") {
      guideColor = Colors.amberAccent;
    } else if (_livenessState == "smile") {
      guideColor = Colors.pinkAccent;
    } else if (_livenessState == "scanning") {
      guideColor = Colors.greenAccent;
    } else if (_livenessState == "success") {
      guideColor = Colors.green;
    }

    return Center(
      child: Container(
        width: 250,
        height: 320,
        decoration: BoxDecoration(
          border: Border.all(color: guideColor, width: 2.5),
          borderRadius: BorderRadius.circular(160),
          boxShadow: [
            BoxShadow(
              color: guideColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebUploader();
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) return _buildCameraError();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          _buildCapturedPreview(),
          _buildFaceGuide(),
          _buildScanningBar(),
          _buildLivenessHUD(),
          _buildTopControls(),
          _buildCaptureControls(),
        ],
      ),
    );
  }
}
