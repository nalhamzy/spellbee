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

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF6F552B).withValues(alpha: 0.09),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static BoxDecoration card({
    Color color = surface,
    Color border = outline,
    double radius = 22,
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: color,
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
