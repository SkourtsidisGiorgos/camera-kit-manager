import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/kit.dart';
import '../../domain/entities/rental_item.dart';
import '../../domain/entities/equipment_category.dart';
import '../../domain/entities/rental.dart';

class BackupService {
  // Singleton pattern
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  // Create a backup of all data
  Future<File> createBackup({bool includeImages = true}) async {
    try {
      final backupData = await _exportAllData();

      // For web, we only support the JSON data (without images)
      if (kIsWeb) {
        final directory = await getTemporaryDirectory();
        final jsonFile = File(
            '${directory.path}/camera_kit_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await jsonFile.writeAsString(jsonEncode(backupData));
        debugPrint('Web backup created at: ${jsonFile.path}');
        return jsonFile;
      }

      // For mobile, we support full backups with images
      if (includeImages) {
        final zipFile = await _createFullBackup(backupData);
        debugPrint('Full backup with images created at: ${zipFile.path}');
        return zipFile;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final jsonFile = File(
            '${directory.path}/camera_kit_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await jsonFile.writeAsString(jsonEncode(backupData));
        debugPrint('JSON-only backup created at: ${jsonFile.path}');
        return jsonFile;
      }
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  // Create a full backup including images
  Future<File> _createFullBackup(Map<String, dynamic> backupData) async {
    try {
      debugPrint('Starting full backup creation with images...');
      final directory = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create a temporary folder to store backup files
      final backupDir = Directory('${tempDir.path}/backup_$timestamp');
      if (!backupDir.existsSync()) {
        backupDir.createSync();
      }

      debugPrint('Created backup directory: ${backupDir.path}');

      // Save JSON data
      final jsonFile = File('${backupDir.path}/data.json');
      await jsonFile.writeAsString(jsonEncode(backupData));
      debugPrint('JSON data saved to: ${jsonFile.path}');

      // Copy all referenced images
      final imagesDir = Directory('${backupDir.path}/images');
      if (!imagesDir.existsSync()) {
        imagesDir.createSync();
      }
      debugPrint('Images directory created: ${imagesDir.path}');

      // Copy item images and photos
      await _copyItemImagesAndPhotos(backupData, imagesDir);

      // Copy rental images
      await _copyRentalImages(backupData, imagesDir);

      // Create zip archive
      final zipFile =
          File('${directory.path}/camera_kit_backup_$timestamp.zip');
      await _createZipFromDirectory(backupDir.path, zipFile.path);

      debugPrint('Zip file created at: ${zipFile.path}');

      // Clean up temp directory
      if (backupDir.existsSync()) {
        await backupDir.delete(recursive: true);
        debugPrint('Cleaned up temporary backup directory');
      }

      return zipFile;
    } catch (e) {
      debugPrint('Error creating full backup: $e');
      rethrow;
    }
  }

  // Copy both legacy item images and new photo collections
  Future<void> _copyItemImagesAndPhotos(
      Map<String, dynamic> backupData, Directory imagesDir) async {
    final items = backupData['rentalItems'] as List;
    int copiedImages = 0;

    for (var item in items) {
      // Handle legacy image path
      if (item['imagePath'] != null && item['imagePath'].isNotEmpty) {
        final File imageFile = File(item['imagePath']);
        if (await imageFile.exists()) {
          final fileName = imageFile.path.split('/').last;
          final newPath = '${imagesDir.path}/$fileName';
          await imageFile.copy(newPath);
          copiedImages++;

          // Update path in backup data to be relative
          item['imagePath'] = 'images/$fileName';
        } else {
          debugPrint('Image file not found: ${item['imagePath']}');
          // Set to null if file doesn't exist to avoid restore errors
          item['imagePath'] = null;
        }
      }

      // Handle item photos collection
      if (item.containsKey('photos') && item['photos'] is List) {
        final photos = item['photos'] as List;
        for (int i = 0; i < photos.length; i++) {
          final photo = photos[i];
          if (photo['imagePath'] != null && photo['imagePath'].isNotEmpty) {
            final File photoFile = File(photo['imagePath']);
            if (await photoFile.exists()) {
              final fileName = photoFile.path.split('/').last;
              final newPath = '${imagesDir.path}/$fileName';
              await photoFile.copy(newPath);
              copiedImages++;

              // Update path in backup data to be relative
              photos[i]['imagePath'] = 'images/$fileName';
            } else {
              debugPrint('Photo file not found: ${photo['imagePath']}');
              // Set to null if file doesn't exist
              photos[i]['imagePath'] = null;
            }
          }
        }
      }
    }

    debugPrint('Copied $copiedImages item images and photos');
  }

  // Copy rental images to backup folder
  Future<void> _copyRentalImages(
      Map<String, dynamic> backupData, Directory imagesDir) async {
    final rentals = backupData['rentals'] as List;
    int copiedImages = 0;

    for (var rental in rentals) {
      if (rental['imagePath'] != null && rental['imagePath'].isNotEmpty) {
        final File imageFile = File(rental['imagePath']);
        if (await imageFile.exists()) {
          final fileName = imageFile.path.split('/').last;
          final newPath = '${imagesDir.path}/$fileName';
          await imageFile.copy(newPath);
          copiedImages++;

          // Update path in backup data to be relative
          rental['imagePath'] = 'images/$fileName';
        } else {
          debugPrint('Rental image not found: ${rental['imagePath']}');
          // Set to null if file doesn't exist
          rental['imagePath'] = null;
        }
      }
    }

    debugPrint('Copied $copiedImages rental images');
  }

  // Export all data from Hive boxes
  Future<Map<String, dynamic>> _exportAllData() async {
    final kits =
        Hive.box<Kit>('kits').values.map((kit) => kit.toMap()).toList();
    final rentalItems = Hive.box<RentalItem>('rentalItems')
        .values
        .map((item) => item.toMap())
        .toList();
    final categories = Hive.box<EquipmentCategory>('equipmentCategories')
        .values
        .map((category) => {
              'id': category.id,
              'name': category.name,
              'predefinedItems': category.predefinedItems,
            })
        .toList();
    final rentals = Hive.box<Rental>('rentals')
        .values
        .map((rental) => rental.toMap())
        .toList();

    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'kits': kits,
      'rentalItems': rentalItems,
      'equipmentCategories': categories,
      'rentals': rentals,
    };
  }

  // Create a zip archive from a directory
  Future<void> _createZipFromDirectory(
      String sourceDir, String zipFilePath) async {
    final sourceDirectory = Directory(sourceDir);
    final files = sourceDirectory.listSync(recursive: true);
    debugPrint('Creating zip from ${files.length} files...');

    final archive = Archive();

    for (var file in files) {
      if (file is File) {
        final relativePath = file.path.substring(sourceDir.length + 1);
        final data = await file.readAsBytes();
        final archiveFile = ArchiveFile(relativePath, data.length, data);
        archive.addFile(archiveFile);
        debugPrint('Added to archive: $relativePath (${data.length} bytes)');
      }
    }

    final zipData = ZipEncoder().encode(archive);
    await File(zipFilePath).writeAsBytes(zipData);
    debugPrint('Zip archive created successfully');
  }

  Future<void> shareBackup({bool includeImages = true}) async {
    try {
      final backupFile = await createBackup(includeImages: includeImages);
      debugPrint('Sharing backup: ${backupFile.path}');
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Camera Kit Manager Backup',
        text: 'Camera Kit Manager Backup - ${DateTime.now().toString()}',
      );
    } catch (e) {
      debugPrint('Error sharing backup: $e');
      rethrow;
    }
  }
}
