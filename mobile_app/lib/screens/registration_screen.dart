import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/tesla_theme.dart';
import 'camera_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _classController = TextEditingController();
  final _departmentController = TextEditingController();
  String? _base64Image;
  bool _isLoading = false;

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fill all fields and capture a photo.")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.register(
        _nameController.text,
        _emailController.text,
        _base64Image!,
        className: _classController.text.trim(),
        department: _departmentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Success: ${response['name']} registered")));
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('Registration error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: ApiService.customBaseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TeslaTheme.surfaceHigh,
        title: const Text('Backend Server Settings', style: TextStyle(color: TeslaTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeslaTextField(
              controller: controller,
              labelText: 'Server URL / IP',
              prefixIcon: Icons.dns_outlined,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current: ${ApiService.baseUrl}',
                style: const TextStyle(color: TeslaTheme.primary, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TeslaTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              final prefs = await SharedPreferences.getInstance();
              if (newUrl.isEmpty) {
                await prefs.remove('custom_backend_url');
                ApiService.setCustomBaseUrl('');
              } else {
                await prefs.setString('custom_backend_url', newUrl);
                ApiService.setCustomBaseUrl(newUrl);
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backend URL: ${ApiService.baseUrl}')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: TeslaTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _classController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Register User', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Server Settings',
            onPressed: _isLoading ? null : _showServerSettings,
            icon: const Icon(Icons.settings_outlined, color: TeslaTheme.onSurfaceVariant),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeslaTextField(
                controller: _nameController,
                labelText: 'Full Name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              TeslaTextField(
                controller: _emailController,
                labelText: 'Email Address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TeslaTextField(
                controller: _classController,
                labelText: 'Class / Role',
                prefixIcon: Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              TeslaTextField(
                controller: _departmentController,
                labelText: 'Department',
                prefixIcon: Icons.business_outlined,
              ),
              const SizedBox(height: 32),
              
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: TeslaTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TeslaTheme.outlineVariant),
                ),
                child: _base64Image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.face_retouching_natural, size: 64, color: TeslaTheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: TeslaButton(
                              height: 44,
                              isSecondary: true,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CameraScreen(
                                    onImageCaptured: (img) =>
                                        setState(() => _base64Image = img),
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text("Capture Face"),
                                ],
                              ),
                            ),
                          )
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 64, color: Color(0xFF4ADE80)),
                          const SizedBox(height: 16),
                          const Text("Image Captured Successfully!",
                              style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _base64Image = null),
                            child: const Text("Retake Photo", style: TextStyle(color: TeslaTheme.primary)),
                          )
                        ],
                      ),
              ),
              const SizedBox(height: 48),
              
              TeslaButton(
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
                child: const Text("Complete Registration"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
