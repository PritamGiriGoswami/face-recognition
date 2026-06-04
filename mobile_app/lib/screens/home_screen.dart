import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../widgets/gps_widget.dart';
import '../theme/tesla_theme.dart';
import 'attendance_screen.dart';
import 'registration_screen.dart';
import 'student_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _backendStatus;
  bool _checkingBackend = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    setState(() => _checkingBackend = true);
    final err = await ApiService.testConnection();
    if (mounted) {
      setState(() {
        _backendStatus = err;
        _checkingBackend = false;
      });
    }
  }

  void _openDashboardDialog(BuildContext context) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TeslaTheme.surfaceHigh,
        title: const Text(
          'Student/Employee Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: TeslaTheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your registered email address to view statistics, calendar heatmap, and daily logs.',
              style: TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TeslaTextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              labelText: 'Registered Email',
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TeslaTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentDashboardScreen(email: email),
                ),
              );
            },
            child: const Text('View Dashboard', style: TextStyle(color: TeslaTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiService.customBaseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TeslaTheme.surfaceHigh,
        title: const Text(
          'Backend Server Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: TeslaTheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the backend server URL or IP address.',
              style: TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TeslaTextField(
              controller: controller,
              labelText: 'Server URL / IP',
              prefixIcon: Icons.dns,
            ),
            const SizedBox(height: 8),
            Text(
              'Current active URL: ${ApiService.baseUrl}',
              style: const TextStyle(fontSize: 12, color: TeslaTheme.primary),
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
              try {
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
                    SnackBar(
                      content: Text('Backend URL updated: ${ApiService.baseUrl}'),
                      backgroundColor: TeslaTheme.surfaceHighest,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving settings: $e')),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: TeslaTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _handleNav(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
      ).then((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    } else if (index == 2) {
      _openDashboardDialog(context);
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Gurukul', style: TextStyle(fontSize: 20, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: TeslaTheme.onSurfaceVariant),
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: TeslaTheme.surfaceHigh,
        selectedItemColor: TeslaTheme.onSurface,
        unselectedItemColor: TeslaTheme.onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _handleNav,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Stats'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sleek Header
              const Text(
                'Status',
                style: TextStyle(
                  color: TeslaTheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI System Active',
                style: TextStyle(
                  color: TeslaTheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 48),

              // Actions Header
              const Text(
                'Controls',
                style: TextStyle(
                  color: TeslaTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Primary Action
              TeslaCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TeslaTheme.surfaceHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: TeslaTheme.onSurface),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark Attendance',
                            style: TextStyle(
                              color: TeslaTheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Face ID & AI Verification',
                            style: TextStyle(
                              color: TeslaTheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TeslaTheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Actions
              Row(
                children: [
                  Expanded(
                    child: TeslaCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person_add_outlined, color: TeslaTheme.onSurfaceVariant, size: 28),
                          SizedBox(height: 16),
                          Text(
                            'Register',
                            style: TextStyle(
                              color: TeslaTheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeslaCard(
                      onTap: () => _openDashboardDialog(context),
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.dashboard_outlined, color: TeslaTheme.onSurfaceVariant, size: 28),
                          SizedBox(height: 16),
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              color: TeslaTheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Recent Activity or Live Feed
              const Text(
                'Recent Activity',
                style: TextStyle(
                  color: TeslaTheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const _LiveFeed(),

              const SizedBox(height: 24),
              _BackendStatus(
                status: _backendStatus,
                checking: _checkingBackend,
                onRetry: _checkBackend,
              ),
              const SizedBox(height: 16),
              const GpsWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendStatus extends StatelessWidget {
  final String? status;
  final bool checking;
  final VoidCallback onRetry;

  const _BackendStatus({
    required this.status,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: TeslaTheme.primary),
            ),
            SizedBox(width: 12),
            Text('Connecting to server...',
              style: TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }

    if (status == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onRetry,
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: TeslaTheme.error, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cannot connect to server. Tap to retry.',
                style: TextStyle(color: TeslaTheme.error, fontSize: 13),
              ),
            ),
            const Icon(Icons.refresh, color: TeslaTheme.error, size: 16),
          ],
        ),
      ),
    );
  }
}

class _LiveFeed extends StatelessWidget {
  const _LiveFeed();

  @override
  Widget build(BuildContext context) {
    return TeslaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: TeslaTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Aryan K. marked present at 9:01 AM',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: TeslaTheme.onSurface, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: TeslaTheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
