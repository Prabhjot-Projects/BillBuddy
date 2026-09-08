import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class SqliteReceiptEventRepository implements ReceiptEventRepository {
  final DatabaseService _databaseService;

  SqliteReceiptEventRepository(this._databaseService);

  Database get _db => _databaseService.instance;

  @override
  Future<Result<ReceiptEvent>> add(ReceiptEvent event) async {
    try {
      final id = await _db.insert(ReceiptSchema.receiptEventsTable, {
        'receiptId': event.receiptId,
        'eventType': event.eventType,
        'summary': event.summary,
        'createdAt': event.createdAt.toIso8601String(),
      });
      return Result.success(
        ReceiptEvent(
          id: id,
          receiptId: event.receiptId,
          eventType: event.eventType,
          summary: event.summary,
          createdAt: event.createdAt,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save activity history.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<ReceiptEvent>>> getAll() async {
    try {
      final rows = await _db.query(
        ReceiptSchema.receiptEventsTable,
        orderBy: 'createdAt DESC',
      );
      return Result.success(
        rows
            .map(
              (row) => ReceiptEvent(
                id: row['id'] as int,
                receiptId: row['receiptId'] as String,
                eventType: row['eventType'] as String,
                summary: row['summary'] as String,
                createdAt: DateTime.parse(row['createdAt'] as String),
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load activity history.',
          cause: error,
        ),
      );
    }
  }
}
