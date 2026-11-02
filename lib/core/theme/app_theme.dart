import 'package:flutter/material.dart';

/// Identité visuelle ZELVORA : fond nuit profond, accent ambre/corail.
class AppColors {
  static const background = Color(0xFF0B0D12);
  static const surface = Color(0xFF141821);
  static const surfaceHigh = Color(0xFF1C2130);
  static const border = Color(0xFF262C3D);
  static const accent = Color(0xFFFF8A3D);
  static const accentSoft = Color(0xFFFFB37A);
  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFF9AA3B5);

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B3D), Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      focusColor: AppColors.accent.withValues(alpha: 0.25),
      dividerColor: AppColors.border,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
