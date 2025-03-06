import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../../domain/entities/kit.dart';
import '../../domain/entities/rental_item.dart';
import '../../domain/entities/equipment_category.dart';
import '../../domain/entities/rental.dart';
import '../../domain/entities/item_photo.dart';

class ImportService {
  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      debugPrint('Starting restore from: ${backupFile.path}');
      if (backupFile.path.endsWith('.json')) {
        final jsonData = await backupFile.readAsString();
        final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
        return await _importData(backupData, null);
      } else if (backupFile.path.endsWith('.zip')) {
        return await _restoreFromZip(backupFile);
      } else {
        throw Exception('Unsupported backup file format: ${backupFile.path}');
      }
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  // Restore from zip backup
  Future<bool> _restoreFromZip(File zipFile) async {
    try {
      debugPrint('Extracting zip backup: ${zipFile.path}');
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(
          '${tempDir.path}/extract_${DateTime.now().millisecondsSinceEpoch}');
      if (!extractDir.existsSync()) {
        extractDir.createSync();
      }

      debugPrint('Extracting to: ${extractDir.path}');

      // Extract all files
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outFile = File('${extractDir.path}/$filename');
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
          debugPrint('Extracted: $filename (${file.content.length} bytes)');
        }
      }

      // Read JSON data
      final jsonFile = File('${extractDir.path}/data.json');
      if (!jsonFile.existsSync()) {
        throw Exception('Backup is missing data.json file');
      }

      final jsonData = await jsonFile.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      debugPrint('Loaded backup data from JSON');

      // Import data with the extract directory for image references
      final result = await _importData(backupData, extractDir.path);

      // Clean up
      if (extractDir.existsSync()) {
        await extractDir.delete(recursive: true);
        debugPrint('Cleaned up extract directory');
      }

      return result;
    } catch (e) {
      debugPrint('Error restoring from zip: $e');
      return false;
    }
  }

  // Import data from backup
  Future<bool> _importData(
      Map<String, dynamic> backupData, String? extractDirPath) async {
    debugPrint('Importing data from backup...');

    // Clear existing data
    await Hive.box<Kit>('kits').clear();
    await Hive.box<RentalItem>('rentalItems').clear();
    await Hive.box<EquipmentCategory>('equipmentCategories').clear();
    await Hive.box<Rental>('rentals').clear();
    debugPrint('Cleared existing data');

    // Get app document directory for saving images
    final appDir = await getApplicationDocumentsDirectory();
    debugPrint('App documents directory: ${appDir.path}');

    // Restore equipment categories
    if (backupData.containsKey('equipmentCategories')) {
      final categoriesBox = Hive.box<EquipmentCategory>('equipmentCategories');
      final categories = backupData['equipmentCategories'] as List;
      debugPrint('Restoring ${categories.length} equipment categories');

      for (var categoryData in categories) {
        final category = EquipmentCategory(
          id: categoryData['id'],
          name: categoryData['name'],
          predefinedItems: List<String>.from(categoryData['predefinedItems']),
        );
        await categoriesBox.put(category.id, category);
      }
    }

    // Restore kits
    if (backupData.containsKey('kits')) {
      final kitsBox = Hive.box<Kit>('kits');
      final kits = backupData['kits'] as List;
      debugPrint('Restoring ${kits.length} kits');

      for (var kitData in kits) {
        final kit = Kit(
          id: kitData['id'],
          name: kitData['name'],
          dateCreated: DateTime.parse(kitData['dateCreated']),
          isOpen: kitData['isOpen'],
        );
        await kitsBox.put(kit.id, kit);
      }
    }

    // Restore rental items
    if (backupData.containsKey('rentalItems')) {
      final itemsBox = Hive.box<RentalItem>('rentalItems');
      final items = backupData['rentalItems'] as List;
      debugPrint('Restoring ${items.length} rental items');

      for (var itemData in items) {
        String? imagePath = itemData['imagePath'];
        List<ItemPhoto> photos = [];

        // Handle image paths
        if (imagePath != null &&
            imagePath.startsWith('images/') &&
            extractDirPath != null) {
          final sourceFile = File('$extractDirPath/$imagePath');
          if (await sourceFile.exists()) {
            final fileName = sourceFile.path.split('/').last;
            final destPath = '${appDir.path}/$fileName';
            await sourceFile.copy(destPath);
            imagePath = destPath;
            debugPrint('Copied item image to: $destPath');
          } else {
            debugPrint('Source image not found: ${sourceFile.path}');
            imagePath = null;
          }
        }

        // Process item photos
        if (itemData.containsKey('photos') && itemData['photos'] is List) {
          final photosList = itemData['photos'] as List;
          for (var photoData in photosList) {
            String? photoPath = photoData['imagePath'];

            // Handle photo image paths
            if (photoPath != null &&
                photoPath.startsWith('images/') &&
                extractDirPath != null) {
              final sourceFile = File('$extractDirPath/$photoPath');
              if (await sourceFile.exists()) {
                final fileName = sourceFile.path.split('/').last;
                final destPath = '${appDir.path}/$fileName';
                await sourceFile.copy(destPath);
                photoPath = destPath;
                debugPrint('Copied item photo to: $destPath');
              } else {
                debugPrint('Source photo not found: ${sourceFile.path}');
                photoPath = null;
              }
            }

            photos.add(ItemPhoto(
              id: photoData['id'],
              imagePath: photoPath,
              imageDataUrl: photoData['imageDataUrl'],
              dateAdded: DateTime.parse(photoData['dateAdded']),
              caption: photoData['caption'],
            ));
          }
        }

        // Create and save the item
        final item = RentalItem(
          id: itemData['id'],
          kitId: itemData['kitId'],
          name: itemData['name'],
          dateAdded: DateTime.parse(itemData['dateAdded']),
          imagePath: imagePath,
          imageDataUrl: itemData['imageDataUrl'],
          category: itemData['category'],
          notes: itemData['notes'],
          cost: itemData['cost']?.toDouble(),
          photos: photos,
        );
        await itemsBox.put(item.id, item);
      }
    }

    // Restore rentals
    if (backupData.containsKey('rentals')) {
      final rentalsBox = Hive.box<Rental>('rentals');
      final rentals = backupData['rentals'] as List;
      debugPrint('Restoring ${rentals.length} rentals');

      for (var rentalData in rentals) {
        String? imagePath = rentalData['imagePath'];

        // Handle image paths
        if (imagePath != null &&
            imagePath.startsWith('images/') &&
            extractDirPath != null) {
          final sourceFile = File('$extractDirPath/$imagePath');
          if (await sourceFile.exists()) {
            final fileName = sourceFile.path.split('/').last;
            final destPath = '${appDir.path}/$fileName';
            await sourceFile.copy(destPath);
            imagePath = destPath;
            debugPrint('Copied rental image to: $destPath');
          } else {
            debugPrint('Source rental image not found: ${sourceFile.path}');
            imagePath = null;
          }
        }

        DateTime? endDate;
        if (rentalData['endDate'] != null) {
          endDate = DateTime.parse(rentalData['endDate']);
        }

        final kitIds = rentalData['kitIds'] != null
            ? List<String>.from(rentalData['kitIds'])
            : <String>[];

        final rental = Rental(
          id: rentalData['id'],
          name: rentalData['name'],
          startDate: DateTime.parse(rentalData['startDate']),
          endDate: endDate,
          address: rentalData['address'],
          latitude: rentalData['latitude'],
          longitude: rentalData['longitude'],
          imagePath: imagePath,
          imageDataUrl: rentalData['imageDataUrl'],
          notes: rentalData['notes'],
          kitIds: kitIds,
        );
        await rentalsBox.put(rental.id, rental);
      }
    }

    debugPrint('Backup restoration complete');
    return true;
  }

  Future<File?> pickBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );

      if (result != null && result.files.single.path != null) {
        debugPrint('Selected backup file: ${result.files.single.path}');
        return File(result.files.single.path!);
      }
      debugPrint('No backup file selected');
      return null;
    } catch (e) {
      debugPrint('Error picking backup file: $e');
      return null;
    }
  }
}
