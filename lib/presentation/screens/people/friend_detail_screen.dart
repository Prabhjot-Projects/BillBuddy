import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:flutter/material.dart';

/// One receipt's worth of this friend's involvement, resolved for
/// display: how much they owe (if someone else paid) or are owed (if
/// they paid), computed via the same SplitCalculator used by
/// split_summary_screen — this screen doesn't reimplement the math, it
/// just runs the same calculation from this friend's point of view.
class _FriendReceiptEntry {
  final Receipt receipt;
  final double amount;
  final bool isOwedToThem; // true if this friend was the payer

  _FriendReceiptEntry({
    required this.receipt,
    required this.amount,
    required this.isOwedToThem,
  });
}

class FriendDetailScreen extends StatefulWidget {
  final Friend friend;

  const FriendDetailScreen({super.key, required this.friend});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  late final ItemAssignmentRepository _assignmentRepository;
  late final ReceiptRepository _receiptRepository;

  bool _isLoading = true;
  String? _errorMessage;
  List<_FriendReceiptEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<ItemAssignmentRepository>();
    _receiptRepository = getIt<ReceiptRepository>();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final idsResult = await _assignmentRepository.getReceiptIdsForParticipant(
      widget.friend.id,
    );

    if (!mounted) return;

    if (idsResult.isFailure) {
      setState(() {
        _errorMessage = 'Could not load split history.';
        _isLoading = false;
      });
      return;
    }

    final entries = <_FriendReceiptEntry>[];

    for (final receiptId in idsResult.valueOrNull!) {
      final receiptResult = await _receiptRepository.getById(receiptId);
      final receipt = receiptResult.valueOrNull;
      // Only splittable receipts (payer set, at least assigned items)
      // produce a meaningful entry — a receipt that's only partially
      // set up shouldn't show a bogus $0.00 row.
      if (receipt == null || receipt.paidBy == null) continue;

      final assignmentsResult = await _assignmentRepository
          .getAssignmentsForReceipt(receiptId);
      final assignments = assignmentsResult.valueOrNull ?? {};

      final splitResult = SplitCalculator.calculate(
        receipt: receipt,
        assignments: assignments,
        payerId: receipt.paidBy!,
      );

      if (receipt.paidBy == widget.friend.id) {
        // This friend fronted the money — they're owed the sum of
        // everyone else's share.
        final totalOwedToThemCents = splitResult.owedToPayer.fold<int>(
          0,
          (sum, share) => sum + share.totalCents,
        );
        final totalOwedToThem = totalOwedToThemCents / 100;
        if (totalOwedToThem > 0) {
          entries.add(
            _FriendReceiptEntry(
              receipt: receipt,
              amount: totalOwedToThem,
              isOwedToThem: true,
            ),
          );
        }
      } else {
        // Someone else paid — find this friend's own share, if they
        // have one on this receipt.
        final ownShare = splitResult.shares
            .where((s) => s.participantId == widget.friend.id)
            .firstOrNull;
        if (ownShare != null) {
          entries.add(
            _FriendReceiptEntry(
              receipt: receipt,
              amount: ownShare.total,
              isOwedToThem: false,
            ),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = _entries.fold<double>(
      0,
      (sum, e) => sum + (e.isOwedToThem ? e.amount : -e.amount),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _netBalanceCard(netBalance),
                  const SizedBox(height: 20),
                  const Text(
                    'Split History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('No shared receipts yet.'),
                    )
                  else
                    ..._entries.map(_entryRow),
                ],
              ),
            ),
    );
  }

  Widget _netBalanceCard(double netBalance) {
    final isPositive = netBalance >= 0;
    final label = netBalance == 0
        ? 'All settled up'
        : isPositive
        ? '${widget.friend.name} is owed'
        : '${widget.friend.name} owes';

    return Card(
      color: netBalance == 0
          ? null
          : (isPositive ? Colors.green.shade50 : Colors.orange.shade50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              getIt<CurrencyController>().format(netBalance.abs()),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(_FriendReceiptEntry entry) {
    return ListTile(
      title: Text(entry.receipt.merchantName ?? 'Receipt'),
      subtitle: Text(entry.isOwedToThem ? 'They are owed' : 'They owe'),
      trailing: Text(
        getIt<CurrencyController>().format(entry.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: entry.isOwedToThem
              ? Colors.green.shade700
              : Colors.orange.shade800,
        ),
      ),
    );
  }
}
