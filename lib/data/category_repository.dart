import 'package:camera_kit_manager/domain/entities/equipment_category.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CategoryRepository {
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
