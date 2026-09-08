import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/group.dart';
import 'package:billbuddy/processes/social/group_repository.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'package:flutter/material.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupRepository _repository;
  List<Group> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = getIt<GroupRepository>();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getAll();

    if (!mounted) return;

    result.fold(
      onSuccess: (groups) => setState(() {
        _groups = groups;
        _isLoading = false;
      }),
      onFailure: (failure) => setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _openCreateGroup() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    if (created == true) _loadGroups();
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '"${group.name}" will be deleted. Members are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _repository.delete(group.id);
    if (!mounted) return;

    result.fold(
      onSuccess: (_) => _loadGroups(),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateGroup,
        child: const Icon(Icons.group_add),
      ),
      body: RefreshIndicator(onRefresh: _loadGroups, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_groups.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No groups yet.')),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return ListTile(
          leading: const Icon(Icons.group),
          title: Text(group.name),
          subtitle: Text('${group.memberIds.length} members'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteGroup(group),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(group: group),
              ),
            );
          },
        );
      },
    );
  }
}
