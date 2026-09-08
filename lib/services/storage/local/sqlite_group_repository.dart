import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/group.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/social/group_repository.dart';
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteGroupRepository implements GroupRepository {
  final DatabaseService _databaseService;

  SqliteGroupRepository({required this._databaseService});

  Database get _db => _databaseService.instance;

  @override
  Future<Result<void>> save(Group group) async {
    try {
      // Transactional for the same reason receipt+items is: a group
      // write touches two tables (groups + group_members), and a crash
      // partway through must not leave a group with half its members
      // written.
      await _db.transaction((txn) async {
        await txn.insert(
          SocialSchema.groupsTable,
          group.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.delete(
          SocialSchema.groupMembersTable,
          where: 'groupId = ?',
          whereArgs: [group.id],
        );

        for (final friendId in group.memberIds) {
          await txn.insert(SocialSchema.groupMembersTable, {
            'groupId': group.id,
            'friendId': friendId,
          });
        }
      });

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save the group.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<Group>>> getAll() async {
    try {
      final rows = await _db.query(
        SocialSchema.groupsTable,
        orderBy: 'name COLLATE NOCASE ASC',
      );

      final groups = <Group>[];
      for (final row in rows) {
        final memberIds = await _fetchMemberIds(row['id'] as String);
        groups.add(Group.fromMap(row, memberIds: memberIds));
      }

      return Result.success(groups);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load groups.',
          cause: e,
        ),
      );
    }
  }

  Future<List<String>> _fetchMemberIds(String groupId) async {
    final rows = await _db.query(
      SocialSchema.groupMembersTable,
      columns: ['friendId'],
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    return rows.map((row) => row['friendId'] as String).toList();
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      // group_members rows cascade-delete automatically.
      await _db.delete(
        SocialSchema.groupsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not delete the group.',
          cause: e,
        ),
      );
    }
  }
}
