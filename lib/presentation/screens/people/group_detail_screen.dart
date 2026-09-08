import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/group.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/presentation/screens/receipts/bill_detail_screen.dart';
import 'package:flutter/material.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final ReceiptRepository _receiptRepository;
  late final FriendRepository _friendRepository;

  bool _isLoading = true;
  String? _errorMessage;
  List<Friend> _members = [];
  List<Receipt> _receipts = [];

  @override
  void initState() {
    super.initState();
    _receiptRepository = getIt<ReceiptRepository>();
    _friendRepository = getIt<FriendRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final friendsResult = await _friendRepository.getAll();
    final receiptsResult = await _receiptRepository.getByGroupId(
      widget.group.id,
    );

    if (!mounted) return;

    if (friendsResult.isFailure || receiptsResult.isFailure) {
      setState(() {
        _errorMessage = 'Could not load group details.';
        _isLoading = false;
      });
      return;
    }

    final allFriends = friendsResult.valueOrNull!;
    setState(() {
      _members = allFriends
          .where((f) => widget.group.memberIds.contains(f.id))
          .toList();
      _receipts = receiptsResult.valueOrNull!;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Chip(label: Text('Me')),
                      ..._members.map((f) => Chip(label: Text(f.name))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Split Receipts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_receipts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'No receipts have been split with this group yet.',
                      ),
                    )
                  else
                    ..._receipts.map(
                      (receipt) => ListTile(
                        title: Text(receipt.merchantName ?? 'Receipt'),
                        subtitle: Text(
                          receipt.date != null
                              ? '${receipt.date!.year}-${receipt.date!.month.toString().padLeft(2, '0')}-${receipt.date!.day.toString().padLeft(2, '0')}'
                              : 'Date unknown',
                        ),
                        trailing: Text(
                          getIt<CurrencyController>().format(
                            receipt.total,
                            fallback: '0.00',
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BillDetailScreen(receipt: receipt),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
