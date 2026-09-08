import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/app/theme/theme_controller.dart';
import 'package:billbuddy/services/storage/local/app_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/services/storage/local/data_export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ThemeController _themeController;
  late final AppSettingsService _settingsService;
  late final CurrencyController _currencyController;

  bool _notificationsEnabled = true;
  String _currency = 'CAD';
  String? _versionLabel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _themeController = getIt<ThemeController>();
    _settingsService = getIt<AppSettingsService>();
    _currencyController = getIt<CurrencyController>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifResult = await _settingsService.getNotificationsEnabled();
    final currencyResult = await _settingsService.getCurrency();
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifResult.valueOrNull ?? true;
      _currency = currencyResult.valueOrNull ?? _currencyController.value;
      _currencyController.setCurrency(_currency);
      _versionLabel = '${packageInfo.version} (${packageInfo.buildNumber})';
      _isLoading = false;
    });
  }

  Future<void> _onThemeChanged(ThemeMode? mode) async {
    if (mode == null) return;
    await _themeController.setThemeMode(mode);
    setState(() {}); // reflect the new selection in the radio group
  }

  Future<void> _onNotificationsToggled(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _settingsService.setNotificationsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Appearance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // ValueListenableBuilder rebuilds just this section when
                // the theme changes, so the radio selection stays in
                // sync even if theme were ever changed from elsewhere.
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: _themeController,
                  builder: (context, mode, _) {
                    return Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('System default'),
                          value: ThemeMode.system,
                          groupValue: mode,
                          onChanged: _onThemeChanged,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Light'),
                          value: ThemeMode.light,
                          groupValue: mode,
                          onChanged: _onThemeChanged,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Dark'),
                          value: ThemeMode.dark,
                          groupValue: mode,
                          onChanged: _onThemeChanged,
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Preferences',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  title: const Text('Currency'),
                  subtitle: const Text('Used when displaying bill amounts'),
                  trailing: DropdownButton<String>(
                    value: _currency,
                    items: const [
                      DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _currency = value);
                      _currencyController.setCurrency(value);
                      await _settingsService.setCurrency(value);
                    },
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Enable notifications'),
                  subtitle: const Text(
                    'Reminders and updates about your bills',
                  ),
                  value: _notificationsEnabled,
                  onChanged: _onNotificationsToggled,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'About',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  title: const Text('Version'),
                  trailing: Text(_versionLabel ?? '—'),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export local data'),
                  subtitle: const Text(
                    'Create a JSON backup of your receipts, splits, and history',
                  ),
                  onTap: _exportData,
                ),
              ],
            ),
    );
  }

  Future<void> _exportData() async {
    final result = await getIt<DataExportService>().exportJson();
    if (!mounted) return;
    result.fold(
      onSuccess: (path) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export complete'),
          content: SelectableText('Backup saved to:\n$path'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }
}
