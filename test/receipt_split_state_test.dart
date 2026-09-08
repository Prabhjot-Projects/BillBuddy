import 'package:billbuddy/data/entities/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasSplit is shared by group and individual split receipts', () {
    final item = ReceiptItem(
      id: 'item-1',
      receiptId: 'receipt-1',
      name: 'Coffee',
      price: 4.5,
    );

    final unsplit = Receipt(id: 'receipt-1', items: [item]);
    final groupSplit = Receipt(
      id: 'receipt-1',
      items: [item],
      groupId: 'group-1',
      paidBy: 'me',
    );
    final individualSplit = Receipt(
      id: 'receipt-1',
      items: [item],
      paidBy: 'friend-1',
    );

    expect(unsplit.hasSplit, isFalse);
    expect(groupSplit.hasSplit, isTrue);
    expect(individualSplit.hasSplit, isTrue);
  });
}
