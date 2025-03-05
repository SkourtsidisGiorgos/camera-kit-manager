import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/kit.dart';
import '../models/rental_item.dart';
import '../models/equipment_category.dart';
import '../models/rental.dart';

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
        final jsonFile = File('${directory.path}/camera_kit_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await jsonFile.writeAsString(jsonEncode(backupData));
        return jsonFile;
      }
      
      // For mobile, we support full backups with images
      if (includeImages) {
        return await _createFullBackup(backupData);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final jsonFile = File('${directory.path}/camera_kit_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await jsonFile.writeAsString(jsonEncode(backupData));
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
      final directory = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create a temporary folder to store backup files
      final backupDir = Directory('${tempDir.path}/backup_$timestamp');
      if (!backupDir.existsSync()) {
        backupDir.createSync();
      }
      
      // Save JSON data
      final jsonFile = File('${backupDir.path}/data.json');
      await jsonFile.writeAsString(jsonEncode(backupData));
      
      // Copy all referenced images
      final imagesDir = Directory('${backupDir.path}/images');
      if (!imagesDir.existsSync()) {
        imagesDir.createSync();
      }
      
      await _copyItemImages(backupData, imagesDir);
      await _copyRentalImages(backupData, imagesDir);
      
      // Create zip archive
      final zipFile = File('${directory.path}/camera_kit_backup_$timestamp.zip');
      await _createZipFromDirectory(backupDir.path, zipFile.path);
      
      // Clean up temp directory
      if (backupDir.existsSync()) {
        await backupDir.delete(recursive: true);
      }
      
      return zipFile;
    } catch (e) {
      debugPrint('Error creating full backup: $e');
      rethrow;
    }
  }

  // Copy item images to backup folder
  Future<void> _copyItemImages(Map<String, dynamic> backupData, Directory imagesDir) async {
    final items = backupData['rentalItems'] as List;
    for (var item in items) {
      if (item['imagePath'] != null && item['imagePath'].isNotEmpty) {
        final File imageFile = File(item['imagePath']);
        if (await imageFile.exists()) {
          final fileName = imageFile.path.split('/').last;
          final newPath = '${imagesDir.path}/$fileName';
          await imageFile.copy(newPath);
          
          // Update path in backup data to be relative
          item['imagePath'] = 'images/$fileName';
        }
      }
    }
  }

  // Copy rental images to backup folder
  Future<void> _copyRentalImages(Map<String, dynamic> backupData, Directory imagesDir) async {
    final rentals = backupData['rentals'] as List;
    for (var rental in rentals) {
      if (rental['imagePath'] != null && rental['imagePath'].isNotEmpty) {
        final File imageFile = File(rental['imagePath']);
        if (await imageFile.exists()) {
          final fileName = imageFile.path.split('/').last;
          final newPath = '${imagesDir.path}/$fileName';
          await imageFile.copy(newPath);
          
          // Update path in backup data to be relative
          rental['imagePath'] = 'images/$fileName';
        }
      }
    }
  }

  // Export all data from Hive boxes
  Future<Map<String, dynamic>> _exportAllData() async {
    final kits = Hive.box<Kit>('kits').values.map((kit) => kit.toMap()).toList();
    final rentalItems = Hive.box<RentalItem>('rentalItems').values.map((item) => item.toMap()).toList();
    final categories = Hive.box<EquipmentCategory>('equipmentCategories').values.map((category) => {
      'id': category.id,
      'name': category.name,
      'predefinedItems': category.predefinedItems,
    }).toList();
    final rentals = Hive.box<Rental>('rentals').values.map((rental) => rental.toMap()).toList();
    
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
  Future<void> _createZipFromDirectory(String sourceDir, String zipFilePath) async {
    final sourceDirectory = Directory(sourceDir);
    final files = sourceDirectory.listSync(recursive: true);
    
    final archive = Archive();
    
    for (var file in files) {
      if (file is File) {
        final relativePath = file.path.substring(sourceDir.length + 1);
        final data = await file.readAsBytes();
        final archiveFile = ArchiveFile(relativePath, data.length, data);
        archive.addFile(archiveFile);
      }
    }
    
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await File(zipFilePath).writeAsBytes(zipData);
    }
  }

  // Restore from backup
  Future<bool> restoreFromBackup(File backupFile) async {
    try {
      if (backupFile.path.endsWith('.json')) {
        final jsonData = await backupFile.readAsString();
        final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
        return await _importData(backupData, null);
      } else if (backupFile.path.endsWith('.zip')) {
        return await _restoreFromZip(backupFile);
      } else {
        throw Exception('Unsupported backup file format');
      }
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }

  // Restore from zip backup
  Future<bool> _restoreFromZip(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/extract_${DateTime.now().millisecondsSinceEpoch}');
      if (!extractDir.existsSync()) {
        extractDir.createSync();
      }
      
      // Extract all files
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final outFile = File('${extractDir.path}/$filename');
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }
      
      // Read JSON data
      final jsonFile = File('${extractDir.path}/data.json');
      if (!jsonFile.existsSync()) {
        throw Exception('Backup is missing data.json file');
      }
      
      final jsonData = await jsonFile.readAsString();
      final backupData = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Import data with the extract directory for image references
      final result = await _importData(backupData, extractDir.path);
      
      // Clean up
      if (extractDir.existsSync()) {
        await extractDir.delete(recursive: true);
      }
      
      return result;
    } catch (e) {
      debugPrint('Error restoring from zip: $e');
      return false;
    }
  }

  // Import data from backup
  Future<bool> _importData(Map<String, dynamic> backupData, String? extractDirPath) async {
    // Clear existing data
    await Hive.box<Kit>('kits').clear();
    await Hive.box<RentalItem>('rentalItems').clear();
    await Hive.box<EquipmentCategory>('equipmentCategories').clear();
    await Hive.box<Rental>('rentals').clear();
    
    // Get app document directory for saving images
    final appDir = await getApplicationDocumentsDirectory();
    
    // Restore equipment categories
    if (backupData.containsKey('equipmentCategories')) {
      final categoriesBox = Hive.box<EquipmentCategory>('equipmentCategories');
      final categories = backupData['equipmentCategories'] as List;
      
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
      
      for (var itemData in items) {
        String? imagePath = itemData['imagePath'];
        
        // Handle image paths
        if (imagePath != null && imagePath.startsWith('images/') && extractDirPath != null) {
          final sourceFile = File('$extractDirPath/$imagePath');
          if (await sourceFile.exists()) {
            final fileName = sourceFile.path.split('/').last;
            final destPath = '${appDir.path}/$fileName';
            await sourceFile.copy(destPath);
            imagePath = destPath;
          } else {
            imagePath = null;
          }
        }
        
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
        );
        await itemsBox.put(item.id, item);
      }
    }
    
    // Restore rentals
    if (backupData.containsKey('rentals')) {
      final rentalsBox = Hive.box<Rental>('rentals');
      final rentals = backupData['rentals'] as List;
      
      for (var rentalData in rentals) {
        String? imagePath = rentalData['imagePath'];
        
        // Handle image paths
        if (imagePath != null && imagePath.startsWith('images/') && extractDirPath != null) {
          final sourceFile = File('$extractDirPath/$imagePath');
          if (await sourceFile.exists()) {
            final fileName = sourceFile.path.split('/').last;
            final destPath = '${appDir.path}/$fileName';
            await sourceFile.copy(destPath);
            imagePath = destPath;
          } else {
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
    
    return true;
  }

  // Export backup to share
  Future<void> shareBackup({bool includeImages = true}) async {
    try {
      final backupFile = await createBackup(includeImages: includeImages);
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

  // Import backup from file
  Future<File?> pickBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking backup file: $e');
      return null;
    }
  }
}
