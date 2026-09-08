import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteFriendRepository implements FriendRepository {
  final DatabaseService _databaseService;

  SqliteFriendRepository({required this._databaseService});

  Database get _db => _databaseService.instance;

  @override
  Future<Result<void>> add(Friend friend) async {
    try {
      await _db.insert(
        SocialSchema.friendsTable,
        friend.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save the friend.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<Friend>>> getAll() async {
    try {
      final rows = await _db.query(
        SocialSchema.friendsTable,
        orderBy: 'name COLLATE NOCASE ASC',
      );
      return Result.success(rows.map(Friend.fromMap).toList());
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load friends.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      // group_members rows referencing this friend are removed
      // automatically via ON DELETE CASCADE (see SocialSchema +
      // PRAGMA foreign_keys = ON in DatabaseService) — deleting a
      // friend correctly removes them from any groups they were in.
      await _db.delete(
        SocialSchema.friendsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not delete the friend.',
          cause: e,
        ),
      );
    }
  }
}
