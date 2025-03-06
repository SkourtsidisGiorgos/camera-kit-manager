import 'package:camera_kit_manager/core/services/theme_provider_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'domain/entities/kit.dart';
import 'domain/entities/rental_item.dart';
import 'domain/entities/equipment_category.dart';
import 'domain/entities/rental.dart';
import 'domain/entities/item_photo.dart';
import 'presentation/screens/kit/kit_list_screen.dart';
import 'presentation/screens/rental/rental_list_screen.dart';
import 'presentation/screens/settings/backup_settings_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'core/utils/constants.dart';
import 'data/category_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(KitAdapter());
  Hive.registerAdapter(RentalItemAdapter());
  Hive.registerAdapter(EquipmentCategoryAdapter());
  Hive.registerAdapter(RentalAdapter());
  Hive.registerAdapter(ItemPhotoAdapter());

  await Hive.openBox<Kit>('kits');
  await Hive.openBox<RentalItem>('rentalItems');
  await Hive.openBox<EquipmentCategory>('equipmentCategories');
  await Hive.openBox<Rental>('rentals');

  final categoryRepository = CategoryRepository();
  await categoryRepository.initDefaultCategoriesIfEmpty();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: AppStrings.appTitle,
          theme: ThemeData(
            primarySwatch: AppColors.primary,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: AppColors.primary,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            colorScheme: const ColorScheme.dark().copyWith(
              primary: AppColors.primary,
            ),
          ),
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainScreen(),
        );
      },
    );
  }
}

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
