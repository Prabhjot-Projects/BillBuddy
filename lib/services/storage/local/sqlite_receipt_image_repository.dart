import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/receipt/receipt_image_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class SqliteReceiptImageRepository implements ReceiptImageRepository {
  final DatabaseService _databaseService;

  SqliteReceiptImageRepository({required DatabaseService databaseService})
    : _databaseService = databaseService;

  Database get _db => _databaseService.instance;

  @override
  Future<Result<void>> savePages({
    required String receiptId,
    required List<String> imagePaths,
  }) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete(
          ReceiptSchema.receiptImagesTable,
          where: 'receiptId = ?',
          whereArgs: [receiptId],
        );
        for (var index = 0; index < imagePaths.length; index++) {
          await txn.insert(ReceiptSchema.receiptImagesTable, {
            'receiptId': receiptId,
            'imagePath': imagePaths[index],
            'pageNumber': index + 1,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      });
      return Result.success(null);
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save receipt pages.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<String>>> getPages(String receiptId) async {
    try {
      final rows = await _db.query(
        ReceiptSchema.receiptImagesTable,
        columns: ['imagePath'],
        where: 'receiptId = ?',
        whereArgs: [receiptId],
        orderBy: 'pageNumber ASC',
      );
      return Result.success(
        rows.map((row) => row['imagePath'] as String).toList(),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load receipt pages.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deletePages(String receiptId) async {
    try {
      await _db.delete(
        ReceiptSchema.receiptImagesTable,
        where: 'receiptId = ?',
        whereArgs: [receiptId],
      );
      return Result.success(null);
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not delete receipt pages.',
          cause: error,
        ),
      );
    }
  }
}
