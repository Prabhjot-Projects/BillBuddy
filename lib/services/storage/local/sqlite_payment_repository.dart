import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/payment.dart';
import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:billbuddy/processes/receipt/payment_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class SqlitePaymentRepository implements PaymentRepository {
  final DatabaseService _databaseService;

  SqlitePaymentRepository(this._databaseService);

  Database get _db => _databaseService.instance;

  @override
  Future<Result<Payment>> add(Payment payment) async {
    try {
      final id = await _db.insert(ReceiptSchema.paymentsTable, {
        'receiptId': payment.receiptId,
        'fromParticipantId': payment.fromParticipantId,
        'toParticipantId': payment.toParticipantId,
        'amountCents': payment.amountCents,
        'paidAt': payment.paidAt.toIso8601String(),
        'note': payment.note,
      });
      await _db.insert(ReceiptSchema.receiptEventsTable, {
        'receiptId': payment.receiptId,
        'eventType': 'payment_recorded',
        'summary': 'Settlement recorded',
        'createdAt': payment.paidAt.toIso8601String(),
      });
      return Result.success(
        Payment(
          id: id,
          receiptId: payment.receiptId,
          fromParticipantId: payment.fromParticipantId,
          toParticipantId: payment.toParticipantId,
          amountCents: payment.amountCents,
          paidAt: payment.paidAt,
          note: payment.note,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not record the settlement.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<Payment>>> getForReceipt(String receiptId) async {
    try {
      final rows = await _db.query(
        ReceiptSchema.paymentsTable,
        where: 'receiptId = ?',
        whereArgs: [receiptId],
        orderBy: 'paidAt ASC',
      );
      return Result.success(
        rows
            .map(
              (row) => Payment(
                id: row['id'] as int,
                receiptId: row['receiptId'] as String,
                fromParticipantId: row['fromParticipantId'] as String,
                toParticipantId: row['toParticipantId'] as String,
                amountCents: row['amountCents'] as int,
                paidAt: DateTime.parse(row['paidAt'] as String),
                note: row['note'] as String?,
              ),
            )
            .toList(),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not load settlement history.',
          cause: error,
        ),
      );
    }
  }
}
