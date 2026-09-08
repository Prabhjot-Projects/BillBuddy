import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/presentation/screens/receipts/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ManualBillScreen extends StatelessWidget {
  const ManualBillScreen({super.key});

  static const _uuid = Uuid();

  void _start(BuildContext context) {
    final receiptId = _uuid.v4();
    final receipt = Receipt(
      id: receiptId,
      date: DateTime.now(),
      items: [ReceiptItem(id: _uuid.v4(), receiptId: receiptId, name: '')],
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ReviewScreen(receipt: receipt)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add bill manually')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, size: 52),
            const SizedBox(height: 16),
            Text(
              'Create a bill without a photo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add as many itemized entries as you need, then choose who shares each item.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.add),
                label: const Text('Start manual bill'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
