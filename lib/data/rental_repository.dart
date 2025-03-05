import 'package:hive_flutter/hive_flutter.dart';
import '../domain/entities/rental.dart';
import '../domain/entities/kit.dart';

class RentalRepository {
  Future<void> saveRental(Rental rental) async {
    final box = Hive.box<Rental>('rentals');
    await box.put(rental.id, rental);
  }

  Future<List<Rental>> getAllRentals() async {
    final box = Hive.box<Rental>('rentals');
    return box.values.toList();
  }

  Future<Rental?> getRentalById(String id) async {
    final box = Hive.box<Rental>('rentals');
    return box.get(id);
  }

  Future<void> updateRental(Rental rental) async {
    final box = Hive.box<Rental>('rentals');
    await box.put(rental.id, rental);
  }

  Future<void> deleteRental(String id) async {
    final box = Hive.box<Rental>('rentals');
    await box.delete(id);
  }

  Future<List<Kit>> getKitsByRental(String rentalId) async {
    final rental = await getRentalById(rentalId);
    if (rental == null) {
      return [];
    }

    final kitsBox = Hive.box<Kit>('kits');
    return rental.kitIds
        .map((kitId) => kitsBox.get(kitId))
        .whereType<Kit>()
        .toList();
  }

  // Add a kit to a rental
  Future<void> addKitToRental(String rentalId, String kitId) async {
    final rental = await getRentalById(rentalId);
    if (rental == null) return;

    if (!rental.kitIds.contains(kitId)) {
      final updatedRental = Rental(
        id: rental.id,
        name: rental.name,
        startDate: rental.startDate,
        endDate: rental.endDate,
        address: rental.address,
        latitude: rental.latitude,
        longitude: rental.longitude,
        imagePath: rental.imagePath,
        imageDataUrl: rental.imageDataUrl,
        notes: rental.notes,
        kitIds: [...rental.kitIds, kitId],
      );

      await updateRental(updatedRental);
    }
  }

  // Remove a kit from a rental
  Future<void> removeKitFromRental(String rentalId, String kitId) async {
    final rental = await getRentalById(rentalId);
    if (rental == null) return;

    if (rental.kitIds.contains(kitId)) {
      final updatedKitIds = [...rental.kitIds];
      updatedKitIds.remove(kitId);

      final updatedRental = Rental(
        id: rental.id,
        name: rental.name,
        startDate: rental.startDate,
        endDate: rental.endDate,
        address: rental.address,
        latitude: rental.latitude,
        longitude: rental.longitude,
        imagePath: rental.imagePath,
        imageDataUrl: rental.imageDataUrl,
        notes: rental.notes,
        kitIds: updatedKitIds,
      );

      await updateRental(updatedRental);
    }
  }
}
