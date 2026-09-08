import 'package:billbuddy/data/schema/receipt_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current receipt schema contains production tables and cascades', () {
    expect(
      ReceiptSchema.createReceiptsTableCurrent,
      allOf(contains('groupId TEXT'), contains('paidBy TEXT')),
    );
    expect(
      ReceiptSchema.createReceiptItemsTable,
      contains('ON DELETE CASCADE'),
    );
    expect(
      ReceiptSchema.createReceiptImagesTable,
      allOf(
        contains('pageNumber INTEGER NOT NULL'),
        contains('ON DELETE CASCADE'),
      ),
    );
    expect(
      ReceiptSchema.createPaymentsTable,
      allOf(
        contains('amountCents INTEGER NOT NULL'),
        contains('CHECK(amountCents > 0)'),
        contains('ON DELETE CASCADE'),
      ),
    );
    expect(
      ReceiptSchema.createReceiptEventsTable,
      allOf(
        contains('eventType TEXT NOT NULL'),
        contains('summary TEXT NOT NULL'),
      ),
    );
  });

  test('historical v1 schema does not silently contain later columns', () {
    expect(ReceiptSchema.createReceiptsTableV1, isNot(contains('groupId')));
    expect(ReceiptSchema.createReceiptsTableV1, isNot(contains('paidBy')));
  });
}
