import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/storage/local/user_profile_service.dart';
import 'package:billbuddy/presentation/screens/account/settings_screen.dart';
import 'package:billbuddy/presentation/screens/receipts/activity_history_screen.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserProfileService _profileService;
  final _nameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileService = getIt<UserProfileService>();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await _profileService.getDisplayName();
    if (!mounted) return;

    result.fold(
      onSuccess: (name) => setState(() {
        _nameController.text = name ?? '';
        _isLoading = false;
      }),
      onFailure: (failure) => setState(() {
        _isLoading = false;
      }),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    setState(() => _isSaving = true);
    final result = await _profileService.setDisplayName(name);
    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.'))),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    onChanged: (_) => setState(() {}), // refresh avatar initial
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Activity history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivityHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'This is a local profile only. Sign-in and cloud sync '
                    'across devices will be added later.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
