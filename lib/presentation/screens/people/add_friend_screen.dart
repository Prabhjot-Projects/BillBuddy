import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late final FriendRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = getIt<FriendRepository>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final friend = Friend(id: _uuid.v4(), name: _nameController.text.trim());
    final result = await _repository.add(friend);

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
        title: const Text('Add Friend'),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name *'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
    );
  }
}
