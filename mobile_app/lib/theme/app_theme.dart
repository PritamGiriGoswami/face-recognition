import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light theme using Material 3 and glassmorphism background
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6200EE),
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    // Example glassmorphism container decoration
    extensions: <ThemeExtension<dynamic>>[
      GlassmorphismTheme(
        blurSigma: 12,
        opacity: 0.2,
        borderRadius: BorderRadius.circular(16),
      ),
    ],
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFBB86FC),
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    extensions: <ThemeExtension<dynamic>>[
      GlassmorphismTheme(
        blurSigma: 12,
        opacity: 0.15,
        borderRadius: BorderRadius.circular(16),
      ),
    ],
  );
}

// Simple ThemeExtension to hold glassmorphism parameters
class GlassmorphismTheme extends ThemeExtension<GlassmorphismTheme> {
  final double blurSigma;
  final double opacity;
  final BorderRadius borderRadius;

  const GlassmorphismTheme({
    required this.blurSigma,
    required this.opacity,
    required this.borderRadius,
  });

  @override
  GlassmorphismTheme copyWith(
      {double? blurSigma, double? opacity, BorderRadius? borderRadius}) {
    return GlassmorphismTheme(
      blurSigma: blurSigma ?? this.blurSigma,
      opacity: opacity ?? this.opacity,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  GlassmorphismTheme lerp(ThemeExtension<GlassmorphismTheme>? other, double t) {
    if (other is! GlassmorphismTheme) return this;

    // Avoid reliance on lerpDouble (not available in some Flutter versions).
    double lerpVal(double a, double b, double t) => a + (b - a) * t;

    return GlassmorphismTheme(
      blurSigma: lerpVal(blurSigma, other.blurSigma, t),
      opacity: lerpVal(opacity, other.opacity, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
    );
  }
}
