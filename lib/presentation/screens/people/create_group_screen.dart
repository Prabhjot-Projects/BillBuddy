import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/data/entities/group.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:billbuddy/processes/social/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final FriendRepository _friendRepository;
  late final GroupRepository _groupRepository;

  List<Friend> _allFriends = [];
  final Set<String> _selectedFriendIds = {};
  bool _isLoadingFriends = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _friendRepository = getIt<FriendRepository>();
    _groupRepository = getIt<GroupRepository>();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final result = await _friendRepository.getAll();
    if (!mounted) return;

    result.fold(
      onSuccess: (friends) => setState(() {
        _allFriends = friends;
        _isLoadingFriends = false;
      }),
      onFailure: (failure) => setState(() {
        _loadError = failure.message;
        _isLoadingFriends = false;
      }),
    );
  }

  Future<void> _save() async {
    final nameValid = _formKey.currentState?.validate() ?? false;

    // A group with zero members isn't useful for splitting anything —
    // require at least one selection, same reasoning as "a receipt
    // needs at least one item."
    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one friend.')),
      );
      return;
    }
    if (!nameValid) return;

    setState(() => _isSaving = true);

    final group = Group(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      memberIds: _selectedFriendIds.toList(),
    );

    final result = await _groupRepository.save(group);

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(true),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group name *'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFriendPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendPicker() {
    if (_isLoadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Text(_loadError!);
    }
    if (_allFriends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Add some friends first before creating a group.'),
      );
    }
    return Column(
      children: _allFriends.map((friend) {
        final selected = _selectedFriendIds.contains(friend.id);
        return CheckboxListTile(
          title: Text(friend.name),
          value: selected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedFriendIds.add(friend.id);
              } else {
                _selectedFriendIds.remove(friend.id);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
