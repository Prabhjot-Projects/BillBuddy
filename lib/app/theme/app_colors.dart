import 'package:flutter/material.dart';

/// Semantic colors shared by every screen so foregrounds stay readable when
/// the user switches between light and dark themes.
class AppColors extends ThemeExtension<AppColors> {
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color onAccent;
  final Color danger;

  const AppColors({
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.light;

  @override
  AppColors copyWith({
    Color? textPrimary,
    Color? textMuted,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
    Color? onAccent,
    Color? danger,
  }) {
    return AppColors(
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }

  static const light = AppColors(
    textPrimary: Color(0xff171717),
    textMuted: Color(0xff4b5563),
    surface: Color(0xfffffbf2),
    surfaceAlt: Color(0xfff7f7fb),
    accent: Color(0xff4f46e5),
    onAccent: Colors.white,
    danger: Color(0xffb42318),
  );

  static const dark = AppColors(
    textPrimary: Color(0xfff9fafb),
    textMuted: Color(0xffcbd5e1),
    surface: Color(0xff1f2937),
    surfaceAlt: Color(0xff111827),
    accent: Color(0xffa5b4fc),
    onAccent: Color(0xff111827),
    danger: Color(0xffffb4ab),
  );
}
