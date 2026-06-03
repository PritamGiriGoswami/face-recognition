import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../widgets/gps_widget.dart';
import '../theme/lumina.dart';
import 'admin_login_screen.dart';
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
        title: const Text(
          'Student/Employee Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your registered email address to view statistics, calendar heatmap, and daily logs.',
              style: TextStyle(color: Lumina.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Registered Email',
                hintText: 'e.g. employee@company.com',
                prefixIcon: Icon(Icons.email_outlined),
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
            child: const Text('View Dashboard'),
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
        title: const Text(
          'Backend Server Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the backend server URL or IP address.',
              style: TextStyle(color: Lumina.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Server URL / IP',
                hintText: 'e.g. 192.168.1.100:8000',
                prefixIcon: const Icon(Icons.dns),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: controller.clear,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current active URL: ${ApiService.baseUrl}',
              style: const TextStyle(fontSize: 12, color: Lumina.tertiary),
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
                      content:
                          Text('Backend URL updated: ${ApiService.baseUrl}'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
        );
        break;
      case 2:
        _openDashboardDialog(context);
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EduTopBar(
        actions: [
          IconButton(
            tooltip: 'Server Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: EduBottomNav(
        selectedIndex: 0,
        onSelected: (index) => _handleNav(context, index),
      ),
      body: LuminaShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ScannerHero(),
            const SizedBox(height: 28),
            Text.rich(
              const TextSpan(
                text: 'Welcome to ',
                children: [
                  TextSpan(
                    text: 'Gurukul School',
                    style: TextStyle(color: Lumina.primary),
                  ),
                  TextSpan(text: ' AI Attendance'),
                ],
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Experience frictionless, secure, and intelligent check-ins for the next generation of learners.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Lumina.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 760;
                return GridView.count(
                  crossAxisCount: desktop ? 4 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: desktop ? 1.35 : 1.05,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ActionTile(
                      title: 'Mark Attendance',
                      subtitle: 'Face ID scanning & AI verification',
                      icon: Icons.camera_alt,
                      primary: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttendanceScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      title: 'Register New',
                      subtitle: 'Onboard students & staff',
                      icon: Icons.person_add,
                      accent: Lumina.tertiary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegistrationScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      title: 'My Dashboard',
                      subtitle: 'View your personal logs',
                      icon: Icons.analytics_outlined,
                      accent: Lumina.secondary,
                      onTap: () => _openDashboardDialog(context),
                    ),
                    _ActionTile(
                      title: 'Admin Panel',
                      subtitle: 'School-wide analytics',
                      icon: Icons.dashboard,
                      accent: Lumina.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginScreen(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const _LiveFeed(),
            _BackendStatus(
              status: _backendStatus,
              checking: _checkingBackend,
              onRetry: _checkBackend,
            ),
            const GpsWidget(),
          ],
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
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Connecting to server...',
              style: TextStyle(color: Lumina.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      );
    }

    if (status == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onRetry,
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Lumina.error, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cannot connect to server. Tap to retry.',
                style: TextStyle(color: Lumina.error, fontSize: 12),
              ),
            ),
            const Icon(Icons.refresh, color: Lumina.error, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ScannerHero extends StatefulWidget {
  const _ScannerHero();

  @override
  State<_ScannerHero> createState() => _ScannerHeroState();
}

class _ScannerHeroState extends State<_ScannerHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

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
                borderRadius: BorderRadius.circular(28),
                color: Lumina.surfaceHigh,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Lumina.primary.withValues(alpha: 0.15),
                    blurRadius: 34,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CustomPaint(
                  painter: _GridPainter(),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 24 + (_controller.value * 190),
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Lumina.tertiary.withValues(alpha: 0.95),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Lumina.tertiary.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const _Corner(top: 16, left: 16, topSide: true, leftSide: true),
            const _Corner(top: 16, right: 16, topSide: true, rightSide: true),
            const _Corner(
              bottom: 16,
              left: 16,
              bottomSide: true,
              leftSide: true,
            ),
            const _Corner(
              bottom: 16,
              right: 16,
              bottomSide: true,
              rightSide: true,
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Lumina.primary.withValues(alpha: 0.18),
                border:
                    Border.all(color: Lumina.primary.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Lumina.primary.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.face_retouching_natural,
                  color: Lumina.primary, size: 52),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.accent = Lumina.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Lumina.primaryContainer, Lumina.primary],
            ),
          ),
          child: _TileContent(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: Colors.white,
            textColor: Colors.white,
          ),
        ),
      );
    }

    return GlassCard(
      onTap: onTap,
      accent: accent,
      padding: const EdgeInsets.all(18),
      child: _TileContent(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: accent,
        textColor: Lumina.onSurface,
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _TileContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveFeed extends StatelessWidget {
  const _LiveFeed();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'LIVE FEED',
            style: TextStyle(
              color: Lumina.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aryan K. marked present at 9:01 AM  |  Priya S. verified at Gate 4',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Lumina.onSurface, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Lumina.surfaceBright,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'AI STABLE',
              style: TextStyle(
                color: Lumina.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final bool topSide;
  final bool rightSide;
  final bool bottomSide;
  final bool leftSide;

  const _Corner({
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.topSide = false,
    this.rightSide = false,
    this.bottomSide = false,
    this.leftSide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            top: topSide
                ? const BorderSide(color: Lumina.tertiary, width: 2)
                : BorderSide.none,
            right: rightSide
                ? const BorderSide(color: Lumina.tertiary, width: 2)
                : BorderSide.none,
            bottom: bottomSide
                ? const BorderSide(color: Lumina.tertiary, width: 2)
                : BorderSide.none,
            left: leftSide
                ? const BorderSide(color: Lumina.tertiary, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Lumina.tertiary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
