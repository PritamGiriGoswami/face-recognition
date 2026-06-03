import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
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
        title: const Text('Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Server URL / IP',
                hintText: '192.168.1.100:8000',
                prefixIcon: const Icon(Icons.dns_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: controller.clear,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Current: ${ApiService.baseUrl}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
            child: const Text('Save'),
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
      appBar: AppBar(
        title: const Text('Register User'),
        actions: [
          IconButton(
            tooltip: 'Server Settings',
            onPressed: _isLoading ? null : _showServerSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person))),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classController,
              decoration: InputDecoration(
                  labelText: 'Class',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _departmentController,
              decoration: InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.business)),
            ),
            const SizedBox(height: 32),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: _base64Image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.face, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CameraScreen(
                                        onImageCaptured: (img) =>
                                            setState(() => _base64Image = img),
                                      ))),
                          icon: const Icon(Icons.camera),
                          label: const Text("Capture Face"),
                        )
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text("Image Captured Successfully!",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => setState(() => _base64Image = null),
                          child: const Text("Retake Photo"),
                        )
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Complete Registration",
                      style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
