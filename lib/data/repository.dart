import 'package:hive_flutter/hive_flutter.dart';
import '../models/kit.dart';
import '../models/rental_item.dart';
import '../models/equipment_category.dart';

class DataRepository {
  // Kits
  Future<void> saveKit(Kit kit) async {
    final box = Hive.box<Kit>('kits');
    await box.put(kit.id, kit);
  }

  Future<List<Kit>> getAllKits() async {
    final box = Hive.box<Kit>('kits');
    return box.values.toList();
  }

  Future<void> updateKit(Kit kit) async {
    final box = Hive.box<Kit>('kits');
    await box.put(kit.id, kit);
  }

  Future<void> deleteKit(String id) async {
    final box = Hive.box<Kit>('kits');
    await box.delete(id);

    // Also delete related items
    final itemsBox = Hive.box<RentalItem>('rentalItems');
    final keys = itemsBox.keys.where((key) {
      final item = itemsBox.get(key);
      return item != null && item.kitId == id;
    }).toList();

    for (var key in keys) {
      await itemsBox.delete(key);
    }
  }

  // Rental Items
  Future<void> saveRentalItem(RentalItem item) async {
    final box = Hive.box<RentalItem>('rentalItems');
    await box.put(item.id, item);
  }

  Future<List<RentalItem>> getRentalItemsByKitId(String kitId) async {
    final box = Hive.box<RentalItem>('rentalItems');
    return box.values.where((item) => item.kitId == kitId).toList();
  }

  Future<void> updateRentalItem(RentalItem item) async {
    final box = Hive.box<RentalItem>('rentalItems');
    await box.put(item.id, item);
  }

  Future<void> deleteRentalItem(String id) async {
    final box = Hive.box<RentalItem>('rentalItems');
    await box.delete(id);
  }

  // Equipment Categories
  Future<void> initDefaultCategoriesIfEmpty() async {
    final box = Hive.box<EquipmentCategory>('equipmentCategories');
    if (box.isEmpty) {
      for (var category in EquipmentCategories.defaultCategories) {
        await box.put(category.id, category);
      }
    }
  }

  Future<List<EquipmentCategory>> getAllCategories() async {
    final box = Hive.box<EquipmentCategory>('equipmentCategories');
    return box.values.toList();
  }

  Future<void> saveCategory(EquipmentCategory category) async {
    final box = Hive.box<EquipmentCategory>('equipmentCategories');
    await box.put(category.id, category);
  }

  Future<void> deleteCategory(String id) async {
    final box = Hive.box<EquipmentCategory>('equipmentCategories');
    await box.delete(id);
  }
}
