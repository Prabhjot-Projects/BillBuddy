import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/payment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:flutter/material.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({super.key});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _Balance {
  final String from;
  final String to;
  int cents;

  _Balance(this.from, this.to, this.cents);
}

class _BalancesScreenState extends State<BalancesScreen> {
  bool _loading = true;
  String? _error;
  List<_Balance> _balances = [];
  Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final friends = await getIt<FriendRepository>().getAll();
    final receipts = await getIt<ReceiptRepository>().getAllConfirmed();
    if (receipts.isFailure) {
      if (mounted) {
        setState(() {
          _error = 'Could not load balances.';
          _loading = false;
        });
      }
      return;
    }

    final names = <String, String>{meParticipantId: 'Me'};
    for (final friend in (friends.valueOrNull ?? [])) {
      names[friend.id] = friend.name;
    }
    final totals = <String, _Balance>{};
    for (final receipt in receipts.valueOrNull ?? []) {
      if (receipt.paidBy == null) continue;
      final assignments = await getIt<ItemAssignmentRepository>()
          .getAssignmentsForReceipt(receipt.id);
      final split = SplitCalculator.calculate(
        receipt: receipt,
        assignments: assignments.valueOrNull ?? {},
        payerId: receipt.paidBy!,
      );
      for (final share in split.owedToPayer) {
        final key = '${share.participantId}|${receipt.paidBy}';
        final balance = totals.putIfAbsent(
          key,
          () => _Balance(share.participantId, receipt.paidBy!, 0),
        );
        balance.cents += share.totalCents;
      }
      final payments = await getIt<PaymentRepository>().getForReceipt(
        receipt.id,
      );
      for (final payment in payments.valueOrNull ?? []) {
        final key = '${payment.fromParticipantId}|${payment.toParticipantId}';
        final balance = totals[key];
        if (balance != null) {
          balance.cents = (balance.cents - payment.amountCents).toInt();
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _names = names;
      _balances = totals.values.where((balance) => balance.cents > 0).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _balances.isEmpty
          ? const Center(child: Text('Everyone is settled up.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _balances.length,
                itemBuilder: (context, index) {
                  final balance = _balances[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(
                        '${_names[balance.from] ?? 'Unknown'} owes '
                        '${_names[balance.to] ?? 'Unknown'}',
                      ),
                      trailing: Text(
                        getIt<CurrencyController>().format(balance.cents / 100),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
