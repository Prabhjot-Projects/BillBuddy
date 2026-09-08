import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'review_screen.dart';
import 'package:billbuddy/presentation/widgets/receipt_delete_helper.dart';
import 'package:flutter/material.dart';

/// Shows draft receipts — scans that completed successfully but haven't
/// been reviewed/confirmed by the user yet.
class PendingBillsScreen extends StatefulWidget {
  const PendingBillsScreen({super.key});

  @override
  State<PendingBillsScreen> createState() => _PendingBillsScreenState();
}

class _PendingBillsScreenState extends State<PendingBillsScreen> {
  late final ReceiptRepository _repository;
  List<Receipt> _drafts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = getIt<ReceiptRepository>();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getAllDrafts();

    if (!mounted) return;

    result.fold(
      onSuccess: (drafts) {
        setState(() {
          _drafts = drafts;
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _openReview(Receipt receipt) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ReviewScreen(receipt: receipt)),
    );

    if (saved == true) {
      _loadDrafts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff1f0eb),
      appBar: AppBar(
        title: const Text('Pending Bills'),
        backgroundColor: const Color(0xfff1f0eb),
      ),
      body: RefreshIndicator(onRefresh: _loadDrafts, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_drafts.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 56),
                SizedBox(height: 16),
                Text(
                  'No pending bills',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Your unfinished receipt scans will appear here.'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final receipt = _drafts[index];

        // Dismissible needs a key stable per-item (not per-index) so
        // Flutter can correctly track which item is being swiped even
        // as the list shrinks after a delete.
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
          child: Dismissible(
            key: ValueKey(receipt.id),
            direction: DismissDirection.endToStart,
            background: _deleteBackground(),
            // confirmDismiss runs before the item animates away so the
            // receipt remains visible when deletion is cancelled.
            confirmDismiss: (_) => confirmAndDeleteReceipt(context, receipt),
            onDismissed: (_) {
              setState(() => _drafts.removeAt(index));
            },
            child: _PendingReceiptCard(
              receipt: receipt,
              color: _cardColor(index),
              onTap: () => _openReview(receipt),
            ),
          ),
        );
      },
    );
  }

  Color _cardColor(int index) {
    const colors = [
      Color(0xfff3f4f6),
      Color(0xffe5e7eb),
      Color(0xffd1d5db),
      Color(0xfff9fafb),
    ];
    return colors[index % colors.length];
  }

  Widget _deleteBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}

class _PendingReceiptCard extends StatelessWidget {
  const _PendingReceiptCard({
    required this.receipt,
    required this.color,
    required this.onTap,
  });

  final Receipt receipt;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = receipt.date;
    final dateLabel = date == null
        ? 'Date not set'
        : '${date.day.toString().padLeft(2, '0')} '
              '${_month(date.month)} ${date.year}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      receipt.merchantName ?? 'Untitled receipt',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff232323),
                        fontSize: 21,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xff252525),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(dateLabel),
                  const SizedBox(width: 18),
                  const Icon(Icons.receipt_long_outlined, size: 17),
                  const SizedBox(width: 6),
                  Text('${receipt.items.length} items'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      getIt<CurrencyController>().format(receipt.total),
                      style: const TextStyle(
                        color: Color(0xff232323),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
