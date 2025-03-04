import 'package:hive_flutter/hive_flutter.dart';
import '../models/rental_item.dart';

class ItemRepository {
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
}
