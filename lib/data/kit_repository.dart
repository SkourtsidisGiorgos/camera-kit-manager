import 'package:camera_kit_manager/domain/entities/kit.dart';
import 'package:camera_kit_manager/domain/entities/rental_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class KitRepository {
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
}
