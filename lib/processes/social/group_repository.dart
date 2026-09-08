import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/group.dart';

abstract class GroupRepository {
  /// Creates or fully replaces a group's membership list. Like
  /// ReceiptRepository's upsert-items pattern, this deletes and
  /// re-inserts the group_members rows rather than diffing old vs new
  /// membership — groups have at most a handful of members, so the cost
  /// is negligible and it can never leave a stale membership row behind.
  Future<Result<void>> save(Group group);

  Future<Result<List<Group>>> getAll();

  Future<Result<void>> delete(String id);
}
