import 'package:billbuddy/core/utils/result.dart';

/// Minimal local "account" — just a display name, stored on-device.
/// This is intentionally not a real account system: there's no auth, no
/// server, no cloud sync yet. It exists so the app has *something* to
/// show on a Profile screen and so a display name is available to
/// attribute item assignments to "you" versus a Friend. When real
/// accounts (auth + cloud sync) are built, this local name likely
/// becomes the seed value for the synced profile, not a separate thing
/// that needs to be reconciled.
///
/// This is `services/` because it depends outward on shared_preferences
/// (an external package/platform API), per ARCHITECTURE.md.
abstract class UserProfileService {
  Future<Result<String>> getUserId();
  Future<Result<String?>> getDisplayName();
  Future<Result<void>> setDisplayName(String name);
}
