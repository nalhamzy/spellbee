import 'package:flutter/material.dart';

/// Soft classroom palette inspired by the kid-app references:
/// warm paper, candy accents, and clear high-contrast text.
class AppTheme {
  AppTheme._();

  static const bg = Color(0xFFFFF7E9);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFFFEEC0);
  static const outline = Color(0xFFEBDCB7);

  static const ink = Color(0xFF2E2417);
  static const mute = Color(0xFF75654F);

  static const honey = Color(0xFFFFC83D);
  static const honeyDark = Color(0xFFE59D15);
  static const coral = Color(0xFFFF6B74);
  static const sage = Color(0xFF42B883);
  static const sky = Color(0xFF58A6FF);
  static const violet = Color(0xFF8D72FF);

  static const peach = Color(0xFFFFD6B8);
  static const mint = Color(0xFFDDF7E7);
  static const lilac = Color(0xFFE9E1FF);
  static const rose = Color(0xFFFFE2E7);
  static const aqua = Color(0xFFD9F4FF);

  static const pageGradient = LinearGradient(
    colors: [Color(0xFFFFFBF1), bg, Color(0xFFEFFAFF)],
    stops: [0.0, 0.56, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFFFFF1B6), Color(0xFFE0F7FF), Color(0xFFE9E1FF)],
    stops: [0.0, 0.58, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ctaGradient = LinearGradient(
    colors: [honey, Color(0xFFFFD977), peach],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const surfaceLiftGradient = LinearGradient(
    colors: [surface, Color(0xFFFFFBF2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const voiceGradient = LinearGradient(
    colors: [aqua, Color(0xFFEAF7FF), lilac],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [mint, Color(0xFFEFFFF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const errorGradient = LinearGradient(
    colors: [rose, Color(0xFFFFF3E8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkActionGradient = LinearGradient(
    colors: [ink, Color(0xFF4A3723)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const calmActionGradient = LinearGradient(
    colors: [sage, Color(0xFF65D59D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const navGradient = LinearGradient(
    colors: [surface, Color(0xFFFFF8E6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const selectedNavGradient = LinearGradient(
    colors: [honey, Color(0xFFFFE08B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const premiumGradient = LinearGradient(
    colors: [lilac, Color(0xFFE3F6FF), Color(0xFFFFEAF0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardSheen = LinearGradient(
    colors: [Color(0x99FFFFFF), Color(0x00FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF7C5A1E).withValues(alpha: 0.10),
      blurRadius: 30,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: honeyDark.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: const Color(0xFF5B4215).withValues(alpha: 0.16),
      blurRadius: 34,
      offset: const Offset(0, 18),
    ),
    BoxShadow(
      color: sky.withValues(alpha: 0.14),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> tintedShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.20),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: const Color(0xFF5B4215).withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration card({
    Color color = surface,
    Color border = outline,
    Gradient? gradient,
    double radius = 22,
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: color,
      gradient: gradient ?? cardSheen,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: shadow ? softShadow : null,
    );
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.light(
      primary: honey,
      secondary: violet,
      surface: surface,
      surfaceContainerHighest: surface2,
      onPrimary: ink,
      onSurface: ink,
      error: coral,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: ink,
        fontSize: 40,
        fontWeight: FontWeight.w900,
      ),
      headlineLarge: TextStyle(
        color: ink,
        fontSize: 30,
        fontWeight: FontWeight.w900,
      ),
      headlineMedium: TextStyle(
        color: ink,
        fontSize: 23,
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(color: ink, fontSize: 14),
      bodySmall: TextStyle(color: mute, fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: ink,
    ),
    cardTheme: const CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: honeyDark, width: 2),
      ),
    ),
  );
}
