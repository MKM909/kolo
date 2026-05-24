import 'package:flutter/material.dart';

class KoloColors {
  KoloColors._();

  static const backgroundStart = Color(0xFFE8D5F5);
  static const backgroundEnd = Color(0xFFD4B8E0);
  static const scaffold = Color(0xFFF5EEF8);
  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF9F67F5);
  static const primaryPastel = Color(0xFFEDE9FE);
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFAF8FF);
  static const surfaceDark = Color(0xFF1E1B4B);
  static const surfaceDarkLight = Color(0xFF2D2867);
  static const textPrimary = Color(0xFF1A1523);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const textOnDarkMuted = Color(0xFFB8B0D8);
  static const income = Color(0xFF10B981);
  static const expense = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

class KoloSpacing {
  KoloSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

class KoloTheme {
  KoloTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: KoloColors.primary,
        secondary: KoloColors.primaryLight,
        surface: KoloColors.surfaceWhite,
        error: KoloColors.expense,
        onPrimary: Colors.white,
        onSurface: KoloColors.textPrimary,
      ),
      scaffoldBackgroundColor: KoloColors.scaffold,
      fontFamily: 'DM Sans',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: KoloColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: KoloColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: KoloColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: KoloColors.textPrimary,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: KoloColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KoloColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KoloColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
