import 'package:flutter/material.dart';

/// Bee-inspired palette — warm honey gold + rich charcoal.
class AppTheme {
  AppTheme._();

  // Surface
  static const bg        = Color(0xFFFFFBE8);
  static const surface   = Color(0xFFFFFFFF);
  static const surface2  = Color(0xFFFFF3C4);
  static const outline   = Color(0xFFEADCA8);

  // Text
  static const ink       = Color(0xFF2A2014);
  static const mute      = Color(0xFF6B5A42);

  // Accents
  static const honey     = Color(0xFFF6B800);   // primary
  static const honeyDark = Color(0xFFE09E00);
  static const coral     = Color(0xFFFF6B6B);   // wrong
  static const sage      = Color(0xFF3FB57F);   // correct
  static const sky       = Color(0xFF4A90E2);   // info
  static const violet    = Color(0xFF7B61FF);   // premium

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
              color: ink, fontSize: 40, fontWeight: FontWeight.w900),
          headlineLarge: TextStyle(
              color: ink, fontSize: 28, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(
              color: ink, fontSize: 22, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(
              color: ink, fontSize: 18, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: ink, fontSize: 14),
          bodySmall: TextStyle(color: mute, fontSize: 12),
        ),
        cardTheme: const CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      );
}
