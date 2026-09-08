import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:billbuddy/processes/receipt/receipt_image_repository.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'item_assignment_screen.dart';
import 'package:billbuddy/presentation/widgets/receipt_image_view.dart';
import 'package:flutter/material.dart';

/// Read-only detail view of a confirmed receipt — this is "view saved
/// receipts" as an actual screen rather than just a summary row in a
/// list. Deliberately read-only: editing a *confirmed* receipt is a
/// different, riskier action than editing a draft (it may already be
/// split among group members), so it's out of scope for this screen.
/// If editing a confirmed receipt is needed later, that's a distinct
/// feature decision, not something to sneak in here.
class BillDetailScreen extends StatefulWidget {
  final Receipt receipt;

  const BillDetailScreen({super.key, required this.receipt});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Map<String, List<String>> _assignments = {};
  Map<String, Friend> _friends = {};
  List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    _loadImagePages();
  }

  Future<void> _loadImagePages() async {
    final result = await getIt<ReceiptImageRepository>().getPages(
      widget.receipt.id,
    );
    if (!mounted) return;
    setState(() => _imagePaths = result.valueOrNull ?? []);
  }

  Future<void> _loadAssignments() async {
    final assignments = await getIt<ItemAssignmentRepository>()
        .getAssignmentsForReceipt(widget.receipt.id);
    final friends = await getIt<FriendRepository>().getAll();
    if (!mounted) return;
    setState(() {
      _assignments = assignments.valueOrNull ?? {};
      _friends = {
        for (final friend in (friends.valueOrNull ?? [])) friend.id: friend,
      };
    });
  }

  String _nameFor(String id) =>
      id == meParticipantId ? 'Me' : _friends[id]?.name ?? 'Removed friend';

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: Text(receipt.merchantName ?? 'Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReceiptImageView(
            imagePath: receipt.imagePath,
            imagePaths: _imagePaths,
          ),
          const SizedBox(height: 20),
          Text(
            receipt.merchantName ?? 'Unknown Merchant',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.date != null
                ? '${receipt.date!.year}-${receipt.date!.month.toString().padLeft(2, '0')}-${receipt.date!.day.toString().padLeft(2, '0')}'
                : 'Date unknown',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ...receipt.items.map((item) => _itemRow(context, item)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _totalsRow(context, 'Subtotal', receipt.subtotal),
          _totalsRow(context, 'Tax', receipt.tax),
          _totalsRow(context, 'Total', receipt.total, emphasize: true),
          if (receipt.paidBy != null && _assignments.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Participant shares',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...SplitCalculator.calculate(
              receipt: receipt,
              assignments: _assignments,
              payerId: receipt.paidBy!,
            ).shares.map((share) => _shareRow(context, share)),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.call_split),
            label: Text(
              receipt.groupId != null ? 'View / Edit Split' : 'Split This Bill',
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemAssignmentScreen(receipt: receipt),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ReceiptItem item) {
    final names = (_assignments[item.id] ?? []).map(_nameFor).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text(item.name)),
              Expanded(
                flex: 1,
                child: Text(
                  '×${item.quantity ?? 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  getIt<CurrencyController>().format(item.price, fallback: '?'),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (names.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shared by $names',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shareRow(BuildContext context, SplitShare share) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(_nameFor(share.participantId))),
          Text(getIt<CurrencyController>().format(share.total)),
        ],
      ),
    );
  }

  Widget _totalsRow(
    BuildContext context,
    String label,
    double? value, {
    bool emphasize = false,
  }) {
    final style = emphasize
        ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            getIt<CurrencyController>().format(value, fallback: '0.00'),
            style: style,
          ),
        ],
      ),
    );
  }
}
