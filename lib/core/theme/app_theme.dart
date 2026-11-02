import 'package:flutter/material.dart';

/// Identité visuelle ZELVORA : fond nuit profond, accent ambre/corail.
class AppColors {
  static const background = Color(0xFF0A0A0D);
  static const sidebar = Color(0xFF111114);
  static const surface = Color(0xFF16161B);
  static const surfaceHigh = Color(0xFF202027);
  static const border = Color(0xFF2B2B33);
  static const accent = Color(0xFFFF8C1A);
  static const accentSoft = Color(0xFFFFB25C);
  static const live = Color(0xFFFF3B30);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA1A1AA);

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFFFA940)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Ombre lumineuse orange des éléments sélectionnés.
  static List<BoxShadow> glow([double opacity = 0.45]) => [
        BoxShadow(color: accent.withValues(alpha: opacity), blurRadius: 18, spreadRadius: -2),
      ];

  /// Couleurs des tuiles de chaînes (rotation).
  static const tilePalette = [
    [Color(0xFF8E2A1B), Color(0xFFD9481F)],
    [Color(0xFF3E1D7A), Color(0xFF7B3FD4)],
    [Color(0xFF0E2A5A), Color(0xFF1F5DB8)],
    [Color(0xFF1F4D16), Color(0xFF4C9A2A)],
    [Color(0xFF173B44), Color(0xFF3A7A86)],
    [Color(0xFF2B4A8A), Color(0xFF7FA6E8)],
    [Color(0xFF6A3A08), Color(0xFFE08A1E)],
    [Color(0xFF0F5050), Color(0xFF22A3A3)],
  ];
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
