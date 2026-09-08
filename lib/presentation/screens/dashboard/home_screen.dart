import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/app/theme/app_colors.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/presentation/screens/account/notifications_screen.dart';
import 'package:billbuddy/presentation/screens/account/profile_screen.dart';
import 'package:billbuddy/presentation/screens/people/friends_screen.dart';
import 'package:billbuddy/presentation/screens/people/groups_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/balances_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/item_assignment_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/manual_bill_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/pending_bills_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/recent_bills_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/review_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/scan_screen.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/payment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/services/storage/local/user_profile_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // High-contrast neo-brutalist palette inspired by the supplied references.
  static const _ink = Color(0xff171717);
  static const _purple = Color(0xffffd21f);
  static const _paper = Color(0xfffffbf2);
  static const _softPurple = Color(0xff8e7cff);
  static const _peach = Color(0xffff8f70);
  static const _green = Color(0xff93e66a);
  static const _blue = Color(0xff81d7ff);
  List<Friend> _friends = [];
  List<Receipt> _receipts = [];
  List<Receipt> _drafts = [];
  String? _displayName;
  int _owedToMeCents = 0;
  int _iOweCents = 0;
  bool _isLoading = true;

  List<Receipt> get _splitReceipts =>
      _receipts.where((receipt) => receipt.groupId != null).toList();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final friendsResult = await getIt<FriendRepository>().getAll();
    final receiptsResult = await getIt<ReceiptRepository>().getAllConfirmed();
    final draftsResult = await getIt<ReceiptRepository>().getAllDrafts();
    final profileResult = await getIt<UserProfileService>().getDisplayName();
    final balances = await _loadBalanceTotals(
      receiptsResult.valueOrNull ?? const [],
    );
    if (!mounted) return;
    setState(() {
      _friends = friendsResult.valueOrNull ?? [];
      _receipts = receiptsResult.valueOrNull ?? [];
      _drafts = draftsResult.valueOrNull ?? [];
      _displayName = profileResult.valueOrNull;
      _owedToMeCents = balances.$1;
      _iOweCents = balances.$2;
      _isLoading = false;
    });
  }

  Future<(int, int)> _loadBalanceTotals(List<Receipt> receipts) async {
    if (!getIt.isRegistered<ItemAssignmentRepository>() ||
        !getIt.isRegistered<PaymentRepository>()) {
      return (0, 0);
    }
    var owedToMe = 0;
    var iOwe = 0;
    final assignmentsRepository = getIt<ItemAssignmentRepository>();
    final paymentRepository = getIt<PaymentRepository>();
    for (final receipt in receipts) {
      final payer = receipt.paidBy;
      if (payer == null) continue;
      final assignments = await assignmentsRepository.getAssignmentsForReceipt(
        receipt.id,
      );
      final split = SplitCalculator.calculate(
        receipt: receipt,
        assignments: assignments.valueOrNull ?? {},
        payerId: payer,
      );
      final payments = await paymentRepository.getForReceipt(receipt.id);
      for (final share in split.owedToPayer) {
        final paidForShare = (payments.valueOrNull ?? [])
            .where(
              (payment) =>
                  payment.fromParticipantId == share.participantId &&
                  payment.toParticipantId == payer,
            )
            .fold<int>(0, (sum, payment) => sum + payment.amountCents);
        final remaining = (share.totalCents - paidForShare).clamp(
          0,
          share.totalCents,
        );
        if (payer == meParticipantId) {
          owedToMe += remaining;
        } else if (share.participantId == meParticipantId) {
          iOwe += remaining;
        }
      }
    }
    return (owedToMe, iOwe);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _purple,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        onPressed: () => _open(context, const ScanScreen()),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text(
          'Scan receipt',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _ink, width: 3),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _paper,
        indicatorColor: _purple,
        height: 72,
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 11),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: _ink),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: _ink),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: _ink),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: _ink),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          final screens = [
            null,
            const RecentBillsScreen(),
            const FriendsScreen(),
            const ProfileScreen(),
          ];
          if (screens[index] != null) _open(context, screens[index]!);
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                const LinearProgressIndicator(color: _peach, minHeight: 2),
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildBillCard(context),
              const SizedBox(height: 16),
              _buildPreviousSplit(context),
              const SizedBox(height: 18),
              _buildFriendsSection(context),
              const SizedBox(height: 18),
              _buildQuickLinks(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName?.trim().isNotEmpty == true
                    ? _displayName!
                    : 'Welcome',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Bill Splitter',
                style: TextStyle(
                  color: _ink,
                  fontSize: 31,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(context, const NotificationsScreen()),
          icon: const Icon(Icons.notifications_none_rounded, color: _green),
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            if (mounted) _loadDashboardData();
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: _brutalDecoration(_blue, radius: 14),
            child: const Icon(Icons.person_outline_rounded, color: _ink),
          ),
        ),
      ],
    );
  }

  Widget _buildBillCard(BuildContext context) {
    final draft = _drafts.isEmpty ? null : _drafts.first;
    final receipt = draft ?? (_receipts.isEmpty ? null : _receipts.first);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 186),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
        decoration: _brutalDecoration(_paper, radius: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft == null ? 'Total Bill' : 'Continue reviewing',
                    style: TextStyle(color: _ink, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    receipt == null
                        ? '—'
                        : getIt<CurrencyController>().format(receipt.total),
                    style: TextStyle(
                      color: _ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    receipt?.merchantName ?? 'No bills yet',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _ink, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Split with',
                      style: TextStyle(color: _ink, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 58,
                    height: 52,
                    child: Stack(
                      children: [
                        ..._friends
                            .take(3)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) => _miniAvatar(
                                _initial(entry.value.name),
                                entry.key * 14,
                                _avatarColor(entry.key),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 92,
                    height: 42,
                    child: FilledButton(
                      onPressed: () {
                        if (receipt != null) {
                          _open(
                            context,
                            draft == null
                                ? ItemAssignmentScreen(receipt: receipt)
                                : ReviewScreen(receipt: draft),
                          );
                        } else {
                          _open(context, const ScanScreen());
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          receipt == null
                              ? 'Scan receipt'
                              : draft != null
                              ? 'Resume'
                              : receipt.hasSplit
                              ? 'Edit split'
                              : 'Split bill',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniAvatar(String label, double top, Color color) {
    return Positioned(
      top: top,
      right: 3,
      child: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 11,
          backgroundColor: color,
          child: Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousSplit(BuildContext context) {
    final colors = AppColors.of(context);
    final receipt = _splitReceipts.isEmpty ? null : _splitReceipts.first;
    return InkWell(
      onTap: () => _open(context, const RecentBillsScreen()),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [BoxShadow(color: _ink, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _green,
              child: Icon(
                Icons.receipt_long_outlined,
                color: Colors.white70,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt == null
                      ? 'No previous splits'
                      : 'Your previous split',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  receipt == null
                      ? 'Split a confirmed bill to see it here'
                      : getIt<CurrencyController>().format(receipt.total),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsSection(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _brutalDecoration(_paper, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _peach,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.search_rounded, color: _ink, size: 27),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Nearby Friends',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _open(context, const FriendsScreen()),
                child: const Text('See all', style: TextStyle(color: _ink)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_friends.isEmpty)
            Text(
              'Add friends to start splitting bills.',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          _buildBalanceTotals(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBalanceTotals() {
    final currency = getIt<CurrencyController>();
    return Row(
      children: [
        Expanded(
          child: _balanceTile(
            label: 'They owe me',
            amount: currency.format(_owedToMeCents / 100),
            color: _peach,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _balanceTile(
            label: 'I owe',
            amount: currency.format(_iOweCents / 100),
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _balanceTile({
    required String label,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ink, width: 2),
        boxShadow: const [BoxShadow(color: _ink, offset: Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _ink, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            amount,
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String value) =>
      value.trim().isEmpty ? '?' : value.trim()[0].toUpperCase();

  Color _avatarColor(int index) {
    const colors = [
      Color(0xffc58bc5),
      Color(0xffd6aa88),
      Color(0xffa8bd91),
      Color(0xff82aec7),
    ];
    return colors[index % colors.length];
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _quickLink(
          context,
          Icons.pending_actions_rounded,
          'Pending bills',
          const PendingBillsScreen(),
        ),
        _quickLink(
          context,
          Icons.groups_rounded,
          'Groups',
          const GroupsScreen(),
        ),
        _quickLink(
          context,
          Icons.edit_note,
          'Manual bill',
          const ManualBillScreen(),
        ),
        _quickLink(
          context,
          Icons.account_balance_wallet_outlined,
          'Balances',
          const BalancesScreen(),
        ),
      ],
    );
  }

  Widget _quickLink(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen,
  ) {
    return InkWell(
      onTap: () => _open(context, screen),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: [_green, _blue, _peach, _softPurple][label.hashCode.abs() % 4],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [BoxShadow(color: _ink, offset: Offset(4, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: _ink, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _brutalDecoration(Color color, {double radius = 16}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(5, 5))],
    );
  }
}
