import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/kit.dart';
import 'models/rental_item.dart';
import 'models/equipment_category.dart';
import 'screens/kit_list_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for all platforms
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(KitAdapter());
  Hive.registerAdapter(RentalItemAdapter());
  Hive.registerAdapter(EquipmentCategoryAdapter());

  // Open boxes
  await Hive.openBox<Kit>('kits');
  await Hive.openBox<RentalItem>('rentalItems');
  await Hive.openBox<EquipmentCategory>('equipmentCategories');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: ThemeData(
        primarySwatch: AppColors.primary,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const KitListScreen(),
    );
  }
}
