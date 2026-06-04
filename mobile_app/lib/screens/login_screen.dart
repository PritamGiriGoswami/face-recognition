import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/tesla_theme.dart';
import 'admin_panel_screen.dart';
import 'home_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    final email = prefs.getString('user_email');
    if (role != null && email != null && mounted) {
      if (role == 'admin') {
        final token = prefs.getString('admin_token') ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPanelScreen(token: token, email: email),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.loginUser(email, password);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', response['role']);
      await prefs.setString('user_email', response['email']);
      
      if (response['role'] == 'admin') {
        await prefs.setString('admin_token', response['token']);
      }

      if (mounted) {
        if (response['role'] == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPanelScreen(
                token: response['token'],
                email: response['email'],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPassword() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TeslaTheme.surfaceHigh,
        title: const Text('Reset Password', style: TextStyle(color: TeslaTheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email to receive a password reset link.',
              style: TextStyle(color: TeslaTheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TeslaTextField(
              controller: emailController,
              labelText: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: TeslaTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                await AuthService().sendPasswordReset(email);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset link sent to your email.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Send', style: TextStyle(color: TeslaTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeslaTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Minimalistic Icon/Logo
              const Icon(
                Icons.school_outlined,
                size: 64,
                color: TeslaTheme.onSurface,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign In',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: TeslaTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your credentials to access the system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: TeslaTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 64),
              TeslaTextField(
                controller: _emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TeslaTextField(
                controller: _passwordController,
                labelText: 'Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: TeslaTheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: TeslaTheme.primary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TeslaButton(
                onPressed: _login,
                isLoading: _isLoading,
                child: const Text('Sign In'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TeslaButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                      ),
                      isSecondary: true,
                      child: const Text('Sign Up'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
