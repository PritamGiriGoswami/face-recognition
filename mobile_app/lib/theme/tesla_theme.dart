import 'package:flutter/material.dart';

class TeslaTheme {
  // Colors matching the sleek Tesla app aesthetics
  static const surface = Color(0xFF000000); // True black background
  static const surfaceHigh = Color(0xFF111111); // Dark grey cards
  static const surfaceHighest = Color(0xFF1C1C1E); // Slightly lighter grey
  static const surfaceHighlight = Color(0xFF242426); // Lighter highlight

  static const onSurface = Color(0xFFFFFFFF); // High contrast text
  static const onSurfaceVariant = Color(0xFFA0A0A5); // Muted text/icons
  static const outlineVariant = Color(0xFF2C2C2E); // Subtle borders

  static const primary = Color(0xFF3E6AE1); // Tesla Blue
  static const onPrimary = Color(0xFFFFFFFF);
  static const error = Color(0xFFFF453A);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    // Tesla uses a clean geometric sans-serif font (Inter is closest)
    // Using default system sans-serif font to prevent offline crashes
    final textTheme = base.textTheme.apply(
      fontFamily: 'sans-serif',
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A sleek, flat, and borderless card matching the Tesla style.
class TeslaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TeslaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TeslaTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: card,
      ),
    );
  }
}

/// A premium, animated button that scales down slightly when pressed.
class TeslaButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isSecondary;
  final bool isLoading;
  final double height;

  const TeslaButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isSecondary = false,
    this.isLoading = false,
    this.height = 56,
  });

  @override
  State<TeslaButton> createState() => _TeslaButtonState();
}

class _TeslaButtonState extends State<TeslaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _controller.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: disabled ? null : () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSecondary
                ? TeslaTheme.surfaceHighest
                : (disabled
                    ? TeslaTheme.primary.withValues(alpha: 0.5)
                    : TeslaTheme.primary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : DefaultTextStyle(
                  style: TextStyle(
                    color: widget.isSecondary
                        ? TeslaTheme.onSurfaceVariant
                        : TeslaTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}

/// A sleek text field with no visible border, just a subtle background.
class TeslaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;

  const TeslaTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TeslaTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: TeslaTheme.onSurface, fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: TeslaTheme.onSurfaceVariant),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: TeslaTheme.onSurfaceVariant)
              : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
