import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/group.dart';
import 'package:billbuddy/data/entities/participant.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/item_assignment_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/split_calculator.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/processes/social/group_repository.dart';
import 'split_summary_screen.dart';
import 'package:flutter/material.dart';

/// Lets the user choose who was involved in a receipt (via a Group,
/// always including "Me"), who paid, and which of those people share
/// each item.
///
/// Flow: pick a group (scopes who's eligible) -> pick the payer from
/// that group's members -> for each item, a row of chips (one per
/// member, all selected by default) lets the user narrow down who's
/// actually sharing that item.
class ItemAssignmentScreen extends StatefulWidget {
  final Receipt receipt;

  const ItemAssignmentScreen({super.key, required this.receipt});

  @override
  State<ItemAssignmentScreen> createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
  late final GroupRepository _groupRepository;
  late final FriendRepository _friendRepository;
  late final ItemAssignmentRepository _assignmentRepository;
  late final ReceiptRepository _receiptRepository;

  bool _isLoading = true;
  String? _loadError;

  List<Group> _groups = [];
  Map<String, Friend> _friendsById = {};
  Group? _selectedGroup;
  bool _individualSplit = false;
  String? _payerId;

  /// itemId -> set of participant ids currently checked for that item.
  /// Keyed by stable item id (not list position) so state stays valid
  /// even if items were ever reordered or filtered.
  final Map<String, Set<String>> _itemParticipants = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _groupRepository = getIt<GroupRepository>();
    _friendRepository = getIt<FriendRepository>();
    _assignmentRepository = getIt<ItemAssignmentRepository>();
    _receiptRepository = getIt<ReceiptRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final groupsResult = await _groupRepository.getAll();
    final friendsResult = await _friendRepository.getAll();
    final assignmentsResult = await _assignmentRepository
        .getAssignmentsForReceipt(widget.receipt.id);

    if (!mounted) return;

    if (groupsResult.isFailure ||
        friendsResult.isFailure ||
        assignmentsResult.isFailure) {
      setState(() {
        _loadError = 'Could not load groups and friends.';
        _isLoading = false;
      });
      return;
    }

    final groups = groupsResult.valueOrNull!;
    final friends = friendsResult.valueOrNull!;
    final existingAssignments = assignmentsResult.valueOrNull!;

    setState(() {
      _groups = groups;
      _friendsById = {for (final f in friends) f.id: f};

      if (widget.receipt.groupId != null) {
        for (final g in groups) {
          if (g.id == widget.receipt.groupId) {
            _selectedGroup = g;
            break;
          }
        }
      }
      _payerId = widget.receipt.paidBy;

      for (final item in widget.receipt.items) {
        final existing = existingAssignments[item.id];
        if (existing != null && existing.isNotEmpty) {
          _itemParticipants[item.id] = existing.toSet();
        } else if (_selectedGroup != null) {
          _itemParticipants[item.id] = _defaultParticipantIds(_selectedGroup!);
        }
      }

      _isLoading = false;
    });
  }

  Set<String> _defaultParticipantIds(Group group) {
    return {meParticipantId, ...group.memberIds};
  }

  void _onGroupSelected(Group? group) {
    setState(() {
      _selectedGroup = group;
      _payerId = null;
      if (group != null) {
        final defaults = _defaultParticipantIds(group);
        for (final item in widget.receipt.items) {
          _itemParticipants[item.id] = Set.of(defaults);
        }
      } else {
        _itemParticipants.clear();
      }
    });
  }

  List<Friend> _participantsForSelectedGroup() {
    if (_individualSplit) {
      return [meParticipant, ..._friendsById.values];
    }
    if (_selectedGroup == null) return [];
    final members = <Friend>[];
    for (final id in _selectedGroup!.memberIds) {
      final friend = _friendsById[id];
      // Drops any id that no longer resolves to a friend (e.g. deleted
      // after the group was created) rather than crashing.
      if (friend != null) members.add(friend);
    }
    return [meParticipant, ...members];
  }

  void _toggleParticipant(String itemId, String participantId, bool checked) {
    setState(() {
      final set = _itemParticipants.putIfAbsent(itemId, () => {});
      if (checked) {
        set.add(participantId);
      } else {
        set.remove(participantId);
      }
    });
  }

  bool get _canProceed {
    if ((!_individualSplit && _selectedGroup == null) || _payerId == null) {
      return false;
    }
    return SplitCalculator.isFullyAssigned(
      receipt: widget.receipt,
      assignments: _itemParticipants.map((k, v) => MapEntry(k, v.toList())),
    );
  }

  Future<void> _proceedToSummary() async {
    setState(() => _isSaving = true);

    final updatedReceipt = widget.receipt.copyWith(
      groupId: _individualSplit ? null : _selectedGroup!.id,
      paidBy: _payerId,
    );
    await _receiptRepository.confirm(updatedReceipt);

    for (final entry in _itemParticipants.entries) {
      await _assignmentRepository.setAssignments(
        receiptItemId: entry.key,
        participantIds: entry.value.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SplitSummaryScreen(
          receipt: updatedReceipt,
          assignments: _itemParticipants.map((k, v) => MapEntry(k, v.toList())),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Items')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final participants = _participantsForSelectedGroup();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_groups.isNotEmpty)
                DropdownButtonFormField<Group>(
                  initialValue: _selectedGroup,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                      )
                      .toList(),
                  onChanged: _onGroupSelected,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Split individually'),
                subtitle: const Text('Choose friends without creating a group'),
                value: _individualSplit,
                onChanged: (value) => setState(() {
                  _individualSplit = value;
                  _selectedGroup = null;
                  _payerId = null;
                  _itemParticipants.clear();
                  if (value) {
                    final defaults = participants.map((p) => p.id).toSet();
                    for (final item in widget.receipt.items) {
                      _itemParticipants[item.id] = defaults;
                    }
                  }
                }),
              ),
              if (_selectedGroup != null || _individualSplit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _payerId,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: participants
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _payerId = value),
                ),
              ],
            ],
          ),
        ),
        if (_selectedGroup != null || _individualSplit) ...[
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.receipt.items.length,
              itemBuilder: (context, index) {
                final item = widget.receipt.items[index];
                final selected = _itemParticipants[item.id] ?? {};

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              getIt<CurrencyController>().format(
                                item.price,
                                fallback: '?',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: participants.map((p) {
                            final checked = selected.contains(p.id);
                            return FilterChip(
                              label: Text(p.name),
                              selected: checked,
                              onSelected: (value) =>
                                  _toggleParticipant(item.id, p.id, value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: (_canProceed && !_isSaving) ? _proceedToSummary : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('View Split Summary'),
            ),
          ),
        ],
      ],
    );
  }
}
