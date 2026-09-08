import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final receipt = Receipt(
    id: 'receipt-1',
    items: [
      ReceiptItem(
        id: 'item-1',
        receiptId: 'receipt-1',
        name: 'Pizza',
        quantity: 1,
        price: 20,
      ),
    ],
    subtotal: 20,
    tax: 4,
    total: 24,
  );

  test(
    'splits a shared item and preserves the existing equal tax behavior',
    () {
      final result = SplitCalculator.calculate(
        receipt: receipt,
        assignments: const {
          'item-1': ['me', 'friend-1'],
        },
        payerId: 'me',
      );

      expect(result.shares, hasLength(2));
      expect(result.shares[0].itemSubtotal, 10);
      expect(result.shares[0].taxShare, 2);
      expect(result.shares[1].total, 12);
    },
  );

  test('distributes item remainder cents deterministically', () {
    final unevenReceipt = Receipt(
      id: 'receipt-uneven',
      items: [
        ReceiptItem(
          id: 'item-uneven',
          receiptId: 'receipt-uneven',
          name: 'Shared item',
          quantity: 1,
          price: 10,
        ),
      ],
      tax: 1,
    );

    final result = SplitCalculator.calculate(
      receipt: unevenReceipt,
      assignments: const {
        'item-uneven': ['a', 'b', 'c'],
      },
      payerId: 'a',
    );

    expect(result.shares.map((share) => share.itemSubtotal), [
      3.34,
      3.33,
      3.33,
    ]);
    expect(result.shares.map((share) => share.taxShare), [0.34, 0.33, 0.33]);
    expect(
      result.shares.fold<double>(0, (sum, share) => sum + share.total),
      11,
    );
  });

  test('rounds fractional parsed amounts to cents before splitting', () {
    final fractionalReceipt = Receipt(
      id: 'receipt-fractional',
      items: [
        ReceiptItem(
          id: 'item-fractional',
          receiptId: 'receipt-fractional',
          name: 'Item',
          quantity: 1,
          price: 0.1,
        ),
      ],
      tax: 0.1,
    );

    final result = SplitCalculator.calculate(
      receipt: fractionalReceipt,
      assignments: const {
        'item-fractional': ['a', 'b'],
      },
      payerId: 'a',
    );

    expect(result.shares[0].total, 0.1);
    expect(result.shares[1].total, 0.1);
  });

  test('requires every item to have an assignment', () {
    expect(
      SplitCalculator.isFullyAssigned(receipt: receipt, assignments: const {}),
      isFalse,
    );
  });
}
