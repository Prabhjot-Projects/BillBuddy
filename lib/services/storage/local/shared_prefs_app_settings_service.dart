import 'package:billbuddy/core/utils/result.dart';
import 'app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class SharedPrefsAppSettingsService implements AppSettingsService {
  static const _notificationsKey = 'settings.notificationsEnabled';
  static const _currencyKey = 'settings.currency';

  @override
  Future<Result<bool>> getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Defaults to true (opt-out rather than opt-in) since there's
      // nothing intrusive being sent yet — this default should be
      // revisited once real notifications are implemented and their
      // actual content/frequency is known.
      return Result.success(prefs.getBool(_notificationsKey) ?? true);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load settings.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsKey, enabled);
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save settings.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<String>> getCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regionDefault =
          PlatformDispatcher.instance.locale.countryCode == 'CA'
          ? 'CAD'
          : 'USD';
      return Result.success(prefs.getString(_currencyKey) ?? regionDefault);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load currency.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setCurrency(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currency);
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save currency.',
          cause: e,
        ),
      );
    }
  }
}
