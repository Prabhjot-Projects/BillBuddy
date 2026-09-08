import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';
import 'package:flutter/material.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ReceiptEvent> _events = [];
  Map<String, Receipt> _receiptsById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await getIt<ReceiptEventRepository>().getAll();
    final receipts = await getIt<ReceiptRepository>().getAllConfirmed();
    if (!mounted) return;
    setState(() {
      _events = result.valueOrNull ?? [];
      _receiptsById = {
        for (final receipt in (receipts.valueOrNull ?? [])) receipt.id: receipt,
      };
      _error = result.isFailure ? 'Could not load activity history.' : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity history')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _events.isEmpty
          ? const Center(child: Text('No confirmed receipt activity yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const ClampingScrollPhysics(),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return ListTile(
                  leading: Icon(_iconFor(event.eventType)),
                  title: Text(_titleFor(event)),
                  subtitle: Text(_formatDate(event.createdAt)),
                );
              },
            ),
    );
  }

  String _titleFor(ReceiptEvent event) {
    if (event.summary != 'Receipt deleted' &&
        event.summary != 'Receipt confirmed' &&
        event.summary != 'Receipt edited and confirmed') {
      return event.summary;
    }
    final receipt = _receiptsById[event.receiptId];
    if (receipt == null) return event.summary;
    return '${receipt.merchantName ?? 'Receipt'} · '
        '${getIt<CurrencyController>().format(receipt.total, fallback: 'amount unavailable')}';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'deleted':
        return Icons.delete_outline;
      case 'edited':
        return Icons.edit_outlined;
      case 'payment_recorded':
        return Icons.payments_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
