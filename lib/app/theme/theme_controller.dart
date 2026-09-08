import 'package:billbuddy/core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current ThemeMode and persists changes to
/// shared_preferences. A ValueNotifier is enough here — this is a
/// single global setting with one listener (the root MaterialApp) —
/// reaching for a heavier state-management package for one value would
/// be over-engineering relative to what the app actually needs.
class ThemeController extends ValueNotifier<ThemeMode> {
  static const _key = 'settings.themeMode';

  ThemeController() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      value = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<Result<void>> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
      value = mode; // notifies MaterialApp to rebuild with the new theme
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save theme preference.',
          cause: e,
        ),
      );
    }
  }
}
