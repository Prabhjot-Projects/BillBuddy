import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/presentation/widgets/receipt_delete_helper.dart';
import 'package:flutter/material.dart';
import 'bill_detail_screen.dart';

/// Shows confirmed receipts as compact ticket-style cards.
class RecentBillsScreen extends StatefulWidget {
  const RecentBillsScreen({super.key});

  @override
  State<RecentBillsScreen> createState() => _RecentBillsScreenState();
}

class _RecentBillsScreenState extends State<RecentBillsScreen> {
  late final ReceiptRepository _repository;
  List<Receipt> _receipts = [];
  Map<String, List<String>> _participantsByReceipt = {};
  Map<String, Friend> _friendsById = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = getIt<ReceiptRepository>();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final receiptsResult = await _repository.getAllConfirmed();
    final friendsResult = await getIt<FriendRepository>().getAll();
    final assignmentsRepository = getIt<ItemAssignmentRepository>();

    if (!mounted) return;

    if (receiptsResult.isFailure) {
      var message = 'Could not load completed bills.';
      receiptsResult.fold(
        onSuccess: (_) {},
        onFailure: (failure) => message = failure.message,
      );
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      return;
    }

    final receipts = receiptsResult.valueOrNull ?? [];
    final participantMap = <String, List<String>>{};
    for (final receipt in receipts) {
      final assignments = await assignmentsRepository.getAssignmentsForReceipt(
        receipt.id,
      );
      final ids = <String>{
        if (receipt.paidBy != null) receipt.paidBy!,
        ...assignments.valueOrNull?.values.expand((ids) => ids) ?? <String>[],
      };
      participantMap[receipt.id] = ids.toList();
    }

    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _participantsByReceipt = participantMap;
      _friendsById = {
        for (final friend in (friendsResult.valueOrNull ?? []))
          friend.id: friend,
      };
      _isLoading = false;
    });
  }

  void _openDetail(Receipt receipt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillDetailScreen(receipt: receipt)),
    );
  }

  String _nameFor(String id) =>
      id == meParticipantId ? 'Me' : _friendsById[id]?.name ?? 'Removed friend';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff374151),
      appBar: AppBar(
        title: const Text('Completed Bills'),
        backgroundColor: const Color(0xff374151),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(onRefresh: _loadReceipts, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (_receipts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 100, left: 32, right: 32),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white70,
                  size: 56,
                ),
                SizedBox(height: 16),
                Text(
                  'No completed bills yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Confirmed receipts will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _receipts.length,
      itemBuilder: (context, index) {
        final receipt = _receipts[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
          child: Dismissible(
            key: ValueKey(receipt.id),
            direction: DismissDirection.endToStart,
            background: _deleteBackground(),
            confirmDismiss: (_) => confirmAndDeleteReceipt(context, receipt),
            onDismissed: (_) => setState(() => _receipts.removeAt(index)),
            child: _CompletedReceiptCard(
              receipt: receipt,
              participantNames: (_participantsByReceipt[receipt.id] ?? [])
                  .map(_nameFor)
                  .toList(),
              onTap: () => _openDetail(receipt),
            ),
          ),
        );
      },
    );
  }

  Widget _deleteBackground() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
    );
  }
}

class _CompletedReceiptCard extends StatelessWidget {
  const _CompletedReceiptCard({
    required this.receipt,
    required this.participantNames,
    required this.onTap,
  });

  final Receipt receipt;
  final List<String> participantNames;
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff1f2937),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'Receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xff9ca3af), height: 1),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _labelValue(
                      'Title',
                      receipt.merchantName ?? 'Untitled',
                    ),
                  ),
                  const SizedBox(width: 18),
                  _labelValue(
                    'Total Bill',
                    getIt<CurrencyController>().format(receipt.total),
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                dateLabel,
                style: const TextStyle(color: Color(0xff4b5563), fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xffe5e7eb),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _AvatarRow(names: participantNames),
                    const SizedBox(height: 7),
                    const Text(
                      'Splitting With',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xff4b5563), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: Color(0xff1f2937),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return const Text(
        'No participants assigned',
        style: TextStyle(color: Colors.white70),
      );
    }

    return SizedBox(
      height: 34,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: names.take(5).toList().asMap().entries.map((entry) {
            final color = [
              Color(0xffd1d5db),
              Color(0xff9ca3af),
              Color(0xffe5e7eb),
              Color(0xff6b7280),
              Color(0xfff3f4f6),
            ][entry.key];
            return Transform.translate(
              offset: Offset(entry.key == 0 ? 0 : -8, 0),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: color,
                  child: Text(
                    names[entry.key].trim().isEmpty
                        ? '?'
                        : names[entry.key].trim()[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xff1f2937),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
