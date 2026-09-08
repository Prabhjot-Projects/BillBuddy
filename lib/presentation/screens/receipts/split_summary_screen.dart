import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/payment.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:billbuddy/processes/receipt/payment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:flutter/material.dart';

/// Read-only computed result of a split — who owes the payer, and how
/// much. This screen does no writing; all the data it needs (group,
/// payer, item assignments) was already saved by ItemAssignmentScreen
/// before navigating here, which is why this screen can be reopened
/// later (e.g. from Bill Detail) and show the same result deterministically.
class SplitSummaryScreen extends StatefulWidget {
  final Receipt receipt;
  final Map<String, List<String>> assignments;

  const SplitSummaryScreen({
    super.key,
    required this.receipt,
    required this.assignments,
  });

  @override
  State<SplitSummaryScreen> createState() => _SplitSummaryScreenState();
}

class _SplitSummaryScreenState extends State<SplitSummaryScreen> {
  Map<String, Friend> _friendsById = {};
  Map<String, int> _paidCentsByParticipant = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendNames();
  }

  /// Only needed to resolve participant ids to display names — the
  /// calculation itself (SplitCalculator.calculate) doesn't need names
  /// at all, just ids, which keeps that logic free of any dependency on
  /// how people are looked up or displayed.
  Future<void> _loadFriendNames() async {
    final result = await getIt<FriendRepository>().getAll();
    final payments = await getIt<PaymentRepository>().getForReceipt(
      widget.receipt.id,
    );
    if (!mounted) return;
    final paid = <String, int>{};
    for (final payment in (payments.valueOrNull ?? [])) {
      paid.update(
        payment.fromParticipantId,
        (value) => (value + payment.amountCents).toInt(),
        ifAbsent: () => payment.amountCents.toInt(),
      );
    }
    setState(() {
      _friendsById = {for (final f in (result.valueOrNull ?? [])) f.id: f};
      _paidCentsByParticipant = paid;
      _isLoading = false;
    });
  }

  String _nameFor(String participantId) {
    if (participantId == meParticipantId) return 'Me';
    return _friendsById[participantId]?.name ?? 'Removed friend';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final payerId = widget.receipt.paidBy;
    if (payerId == null) {
      // Defensive guard: ItemAssignmentScreen should never navigate here
      // without a payer selected (the button is disabled until one is
      // chosen), but showing a clear message beats a null-check crash
      // if this screen is ever reached some other way in the future.
      return Scaffold(
        appBar: AppBar(title: const Text('Split Summary')),
        body: const Center(
          child: Text('No payer was selected for this receipt.'),
        ),
      );
    }

    final result = SplitCalculator.calculate(
      receipt: widget.receipt,
      assignments: widget.assignments,
      payerId: payerId,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Split Summary')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.receipt.merchantName ?? 'Receipt',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.receipt.date == null
                      ? 'Date unknown'
                      : '${widget.receipt.date!.year}-${widget.receipt.date!.month.toString().padLeft(2, '0')}-${widget.receipt.date!.day.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Total bill: ${getIt<CurrencyController>().format(widget.receipt.total)}',
                ),
                const SizedBox(height: 12),
                Text('Paid by ${_nameFor(payerId)}'),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                ...result.shares.map((share) => _shareRow(share, payerId)),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                _totalOwedRow(result),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Bill saved')));
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Save Bill'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareRow(SplitShare share, String payerId) {
    final remainingCents =
        share.totalCents - (_paidCentsByParticipant[share.participantId] ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              share.participantId == payerId
                  ? '${_nameFor(share.participantId)} (payer)'
                  : '${_nameFor(share.participantId)} owes ${_nameFor(payerId)}',
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                getIt<CurrencyController>().format(share.total),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (share.participantId != payerId)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remainingCents <= 0
                          ? 'Paid'
                          : 'Remaining ${getIt<CurrencyController>().format(remainingCents / 100)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (remainingCents > 0)
                      TextButton(
                        onPressed: () => _settle(
                          participantId: share.participantId,
                          payerId: payerId,
                          maxCents: remainingCents,
                        ),
                        child: const Text('Settle'),
                      ),
                  ],
                ),
              Text(
                'Items ${getIt<CurrencyController>().format(share.itemSubtotal)} · Tax ${getIt<CurrencyController>().format(share.taxShare)}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _settle({
    required String participantId,
    required String payerId,
    required int maxCents,
  }) async {
    final controller = TextEditingController(
      text: (maxCents / 100).toStringAsFixed(2),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle ${_nameFor(participantId)}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: getIt<CurrencyController>().value == 'CAD'
                ? r'$'
                : r'$',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    final amountCents = (amount * 100).round().clamp(1, maxCents);
    final result = await getIt<PaymentRepository>().add(
      Payment(
        receiptId: widget.receipt.id,
        fromParticipantId: participantId,
        toParticipantId: payerId,
        amountCents: amountCents,
        paidAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.fold(
              onSuccess: (_) => '',
              onFailure: (failure) => failure.message,
            ),
          ),
        ),
      );
      return;
    }
    await getIt<ReceiptEventRepository>().add(
      ReceiptEvent(
        receiptId: widget.receipt.id,
        eventType: 'payment_recorded',
        summary:
            'Settlement · ${_nameFor(participantId)} paid '
            '${getIt<CurrencyController>().format(amountCents / 100)} to '
            '${_nameFor(payerId)} for '
            '${widget.receipt.merchantName ?? 'receipt'}',
        createdAt: DateTime.now(),
      ),
    );
    await _loadFriendNames();
  }

  Widget _totalOwedRow(SplitResult result) {
    final totalOwedCents = result.owedToPayer.fold<int>(
      0,
      (sum, share) => sum + share.totalCents,
    );
    final totalOwed = totalOwedCents / 100;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total owed to payer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          getIt<CurrencyController>().format(totalOwed),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
