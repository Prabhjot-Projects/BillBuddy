import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared component defaults for the app's screens.
class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: AppColors.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: AppColors.dark);

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff374151),
      brightness: brightness,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.surfaceAlt,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceAlt,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, 52),
          shape: shape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(220, 52),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(220, 52),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.textMuted),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textMuted,
        textColor: colors.textPrimary,
        shape: shape,
      ),
    );
  }
}
