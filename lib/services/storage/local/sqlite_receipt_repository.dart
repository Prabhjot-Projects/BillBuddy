import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteReceiptRepository implements ReceiptRepository {
  final DatabaseService _databaseService;

  SqliteReceiptRepository({required this._databaseService});

  Database get _db => _databaseService.instance;

  @override
  Future<Result<void>> saveDraft(Receipt receipt) async {
    return _upsert(receipt.copyWith(status: ReceiptStatus.draft));
  }

  @override
  Future<Result<void>> confirm(Receipt receipt) async {
    return _upsert(receipt.copyWith(status: ReceiptStatus.confirmed));
  }

  /// Shared by saveDraft and confirm since both are "write this receipt's
  /// full state to the DB" — the only difference is the status value,
  /// which the caller already baked into the Receipt via copyWith.
  ///
  /// Wrapped in a transaction because a receipt write touches two tables
  /// (receipts + receipt_items). Without a transaction, a crash between
  /// the two writes could leave a receipt row with no items, or stale
  /// item rows from a previous version of the same receipt. Transactions
  /// make the whole operation atomic — it either fully succeeds or fully
  /// rolls back, so the database is never left in a half-written state.
  Future<Result<void>> _upsert(Receipt receipt) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(
          ReceiptSchema.receiptsTable,
          receipt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete existing items for this receipt first, then re-insert
        // the current set. Simpler and safer than diffing old vs new
        // items to figure out which to update/insert/delete — receipts
        // rarely have more than 20-30 items, so the cost of "delete all,
        // re-insert all" is negligible, and it can never leave a stale
        // item behind that the user removed during editing.
        await txn.delete(
          ReceiptSchema.receiptItemsTable,
          where: 'receiptId = ?',
          whereArgs: [receipt.id],
        );

        for (final item in receipt.items) {
          await txn.insert(ReceiptSchema.receiptItemsTable, item.toMap());
        }
      });

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save the receipt.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<Receipt?>> getById(String id) async {
    try {
      final rows = await _db.query(
        ReceiptSchema.receiptsTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) return Result.success(null);

      final items = await _fetchItems(id);
      return Result.success(Receipt.fromMap(rows.first, items: items));
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load the receipt.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<Receipt>>> getAllConfirmed() async {
    return _getAllByStatus(ReceiptStatus.confirmed);
  }

  @override
  Future<Result<List<Receipt>>> getAllDrafts() async {
    return _getAllByStatus(ReceiptStatus.draft);
  }

  @override
  Future<Result<List<Receipt>>> getByGroupId(String groupId) async {
    try {
      final rows = await _db.query(
        ReceiptSchema.receiptsTable,
        where: 'groupId = ? AND status = ?',
        whereArgs: [groupId, ReceiptStatus.confirmed.name],
        orderBy: 'createdAt DESC',
      );

      final receipts = <Receipt>[];
      final itemsByReceipt = await _fetchItemsByReceiptIds(
        rows.map((row) => row['id'] as String).toList(),
      );
      for (final row in rows) {
        final id = row['id'] as String;
        receipts.add(
          Receipt.fromMap(row, items: itemsByReceipt[id] ?? const []),
        );
      }

      return Result.success(receipts);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load group receipts.',
          cause: e,
        ),
      );
    }
  }

  Future<Result<List<Receipt>>> _getAllByStatus(ReceiptStatus status) async {
    try {
      final rows = await _db.query(
        ReceiptSchema.receiptsTable,
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'createdAt DESC',
      );

      final itemsByReceipt = await _fetchItemsByReceiptIds(
        rows.map((row) => row['id'] as String).toList(),
      );
      final receipts = <Receipt>[];
      for (final row in rows) {
        final id = row['id'] as String;
        receipts.add(
          Receipt.fromMap(row, items: itemsByReceipt[id] ?? const []),
        );
      }

      return Result.success(receipts);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load receipts.',
          cause: e,
        ),
      );
    }
  }

  Future<List<ReceiptItem>> _fetchItems(String receiptId) async {
    final rows = await _db.query(
      ReceiptSchema.receiptItemsTable,
      where: 'receiptId = ?',
      whereArgs: [receiptId],
    );
    return rows.map(ReceiptItem.fromMap).toList();
  }

  Future<Map<String, List<ReceiptItem>>> _fetchItemsByReceiptIds(
    List<String> receiptIds,
  ) async {
    final itemsByReceipt = <String, List<ReceiptItem>>{};
    // Keep each IN query below SQLite's 999 bind-variable limit.
    for (var offset = 0; offset < receiptIds.length; offset += 900) {
      final ids = receiptIds.skip(offset).take(900).toList();
      if (ids.isEmpty) continue;
      final placeholders = List.filled(ids.length, '?').join(', ');
      final rows = await _db.rawQuery(
        'SELECT * FROM ${ReceiptSchema.receiptItemsTable} '
        'WHERE receiptId IN ($placeholders)',
        ids,
      );
      for (final row in rows) {
        final item = ReceiptItem.fromMap(row);
        final receiptId = row['receiptId'] as String;
        (itemsByReceipt[receiptId] ??= <ReceiptItem>[]).add(item);
      }
    }
    return itemsByReceipt;
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      // Only need to delete the receipts row — receipt_items rows are
      // removed automatically by ON DELETE CASCADE (see receipt_schema.dart
      // and the PRAGMA foreign_keys = ON in DatabaseService).
      await _db.delete(
        ReceiptSchema.receiptsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not delete the receipt.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<int>> deleteStaleDrafts(Duration olderThan) async {
    try {
      final cutoff = DateTime.now().subtract(olderThan).toIso8601String();
      final deletedCount = await _db.delete(
        ReceiptSchema.receiptsTable,
        where: 'status = ? AND createdAt < ?',
        whereArgs: [ReceiptStatus.draft.name, cutoff],
      );
      return Result.success(deletedCount);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not clean up old drafts.',
          cause: e,
        ),
      );
    }
  }
}
