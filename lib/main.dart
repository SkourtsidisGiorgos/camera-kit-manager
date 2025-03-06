import 'package:camera_kit_manager/core/services/theme_provider_service.dart';
import 'package:camera_kit_manager/presentation/main_screen.dart';
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
