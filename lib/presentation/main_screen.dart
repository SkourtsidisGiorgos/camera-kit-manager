import 'package:camera_kit_manager/core/utils/constants.dart';
import 'package:camera_kit_manager/presentation/screens/kit/kit_list_screen.dart';
import 'package:camera_kit_manager/presentation/screens/rental/rental_list_screen.dart';
import 'package:camera_kit_manager/presentation/screens/settings/backup_settings_screen.dart';
import 'package:camera_kit_manager/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    AppStrings.appTitle,
    'Camera Kit Manager',
  ];

  final _screens = [
    const KitListScreen(),
    const RentalListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openBackupSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupSettingsScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'backup':
                  _openBackupSettings();
                  break;
                case 'settings':
                  _openSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, size: 20),
                    SizedBox(width: 8),
                    Text('Backup & Restore'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Kits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Rentals',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
