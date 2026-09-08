import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteItemAssignmentRepository implements ItemAssignmentRepository {
  final DatabaseService _databaseService;

  SqliteItemAssignmentRepository({required this._databaseService});

  Database get _db => _databaseService.instance;

  @override
  Future<Result<void>> setAssignments({
    required String receiptItemId,
    required List<String> participantIds,
  }) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete(
          ReceiptSchema.itemAssignmentsTable,
          where: 'receiptItemId = ?',
          whereArgs: [receiptItemId],
        );
        for (final participantId in participantIds) {
          await txn.insert(ReceiptSchema.itemAssignmentsTable, {
            'receiptItemId': receiptItemId,
            'friendId': participantId,
          });
        }
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save item assignment.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Map<String, List<String>>>> getAssignmentsForReceipt(
    String receiptId,
  ) async {
    try {
      // Single JOIN query rather than fetching each item's assignments
      // separately — this is exactly the N+1 pattern the repository's
      // doc comment calls out avoiding.
      final rows = await _db.rawQuery(
        '''
        SELECT ia.receiptItemId, ia.friendId
        FROM ${ReceiptSchema.itemAssignmentsTable} ia
        INNER JOIN ${ReceiptSchema.receiptItemsTable} ri
          ON ia.receiptItemId = ri.id
        WHERE ri.receiptId = ?
      ''',
        [receiptId],
      );

      final result = <String, List<String>>{};
      for (final row in rows) {
        final itemId = row['receiptItemId'] as String;
        final friendId = row['friendId'] as String;
        result.putIfAbsent(itemId, () => []).add(friendId);
      }

      return Result.success(result);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load item assignments.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<String>>> getReceiptIdsForParticipant(
    String participantId,
  ) async {
    try {
      // UNION of two cases: participant shares at least one item, OR
      // participant is the receipt's payer. A person who only paid but
      // wasn't assigned any items (e.g. they covered the whole bill as
      // a gift) should still see that receipt in their history.
      final rows = await _db.rawQuery(
        '''
        SELECT DISTINCT ri.receiptId AS receiptId
        FROM ${ReceiptSchema.itemAssignmentsTable} ia
        INNER JOIN ${ReceiptSchema.receiptItemsTable} ri
          ON ia.receiptItemId = ri.id
        WHERE ia.friendId = ?
        UNION
        SELECT DISTINCT id AS receiptId
        FROM ${ReceiptSchema.receiptsTable}
        WHERE paidBy = ?
      ''',
        [participantId, participantId],
      );

      return Result.success(
        rows.map((row) => row['receiptId'] as String).toList(),
      );
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load split history.',
          cause: e,
        ),
      );
    }
  }
}
