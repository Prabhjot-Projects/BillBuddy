import 'package:billbuddy/core/utils/result.dart';

/// Non-theme app preferences. Kept separate from ThemeController (which
/// needs to be a ValueNotifier the UI reacts to live) and from
/// UserProfileService (which is about identity, not preferences) —
/// each of these three has a different shape of consumer, so merging
/// them into one class would mean unrelated reasons to change living
/// in the same file.
abstract class AppSettingsService {
  Future<Result<bool>> getNotificationsEnabled();
  Future<Result<void>> setNotificationsEnabled(bool enabled);
  Future<Result<String>> getCurrency();
  Future<Result<void>> setCurrency(String currency);
}
