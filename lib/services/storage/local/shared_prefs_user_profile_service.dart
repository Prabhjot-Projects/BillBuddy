import 'package:billbuddy/core/utils/result.dart';
import 'user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SharedPrefsUserProfileService implements UserProfileService {
  static const _userIdKey = 'profile.userId';
  static const _displayNameKey = 'profile.displayName';
  static const _uuid = Uuid();

  @override
  Future<Result<String>> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_userIdKey);
      if (id == null || id.isEmpty) {
        id = _uuid.v4();
        await prefs.setString(_userIdKey, id);
      }
      return Result.success(id);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load local user.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<String?>> getDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Result.success(prefs.getString(_displayNameKey));
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load profile.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setDisplayName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_displayNameKey, name);
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save profile.',
          cause: e,
        ),
      );
    }
  }
}
