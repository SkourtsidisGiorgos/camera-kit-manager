import 'package:camera_kit_manager/core/services/theme_provider_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/constants.dart';
import 'backup_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoBackup = false;
  String _appVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getAppVersion();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackup = prefs.getBool('autoBackup') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveAutoBackupSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoBackup', value);
    setState(() {
      _autoBackup = value;
    });
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion =
          'Version ${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  void _openBackupSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Theme Settings
                const ListTile(
                  title: Text(
                    'Display',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme throughout the app'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.setDarkMode(value);
                  },
                ),
                const Divider(),

                // Backup Settings
                const ListTile(
                  title: Text(
                    'Data Management',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Auto Backup'),
                  subtitle: const Text('Automatically backup data weekly'),
                  value: _autoBackup,
                  onChanged: (value) {
                    _saveAutoBackupSetting(value);
                  },
                ),
                ListTile(
                  title: const Text('Backup & Restore'),
                  subtitle:
                      const Text('Manage backups, export, and import data'),
                  leading: const Icon(Icons.backup),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openBackupSettings,
                ),
                const Divider(),

                const ListTile(
                  title: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('App Version'),
                  subtitle: Text(_appVersion),
                  leading: const Icon(Icons.info_outline),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  leading: const Icon(Icons.description),
                  onTap: () {
                    // Show terms dialog or navigate to terms screen
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Terms of Service'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'This is a placeholder for the Terms of Service.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Privacy Policy'),
                  leading: const Icon(Icons.privacy_tip),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Privacy Policy'),
                        content: const SingleChildScrollView(
                          child: Text(
                            "Camera Kit Manager does not collect, store, analyze or share any user data. We currently don't do analytics",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const AboutListTile(
                  icon: Icon(Icons.info),
                  applicationName: AppStrings.appTitle,
                  applicationVersion: 'Version 1.0.0',
                  applicationLegalese: '© 2025 Viterby Solutions',
                  aboutBoxChildren: [
                    SizedBox(height: 10),
                    Text(
                        'Camera Kit Manager helps you keep track of your equipment kits and rentals.'),
                  ],
                ),
              ],
            ),
    );
  }
}
