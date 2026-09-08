import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/friend.dart';
import 'package:billbuddy/processes/social/friend_repository.dart';
import 'add_friend_screen.dart';
import 'friend_detail_screen.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendRepository _repository;
  List<Friend> _friends = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = getIt<FriendRepository>();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getAll();

    if (!mounted) return;

    result.fold(
      onSuccess: (friends) => setState(() {
        _friends = friends;
        _isLoading = false;
      }),
      onFailure: (failure) => setState(() {
        _errorMessage = failure.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddFriendScreen()),
    );
    if (added == true) _loadFriends();
  }

  Future<void> _deleteFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          '${friend.name} will be removed from any groups they are part of.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _repository.delete(friend.id);
    if (!mounted) return;

    result.fold(
      onSuccess: (_) => _loadFriends(),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFriend,
        child: const Icon(Icons.person_add),
      ),
      body: RefreshIndicator(onRefresh: _loadFriends, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_friends.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No friends added yet.')),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(friend.name.substring(0, 1).toUpperCase()),
          ),
          title: Text(friend.name),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteFriend(friend),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FriendDetailScreen(friend: friend),
              ),
            );
          },
        );
      },
    );
  }
}
