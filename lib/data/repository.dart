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

    // Always reset to ensure all categories are available
    await box.clear();

    // Add each default category with a consistent ID
    for (var category in EquipmentCategories.defaultCategories) {
      final newCategory = EquipmentCategory(
        id: 'default_${category.name.replaceAll(' ', '_').toLowerCase()}',
        name: category.name,
        predefinedItems: category.predefinedItems,
      );
      await box.put(newCategory.id, newCategory);
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

  // Force reset and get categories (use this for debugging)
  Future<List<EquipmentCategory>> resetAndGetAllCategories() async {
    await initDefaultCategoriesIfEmpty();
    return getAllCategories();
  }
}
