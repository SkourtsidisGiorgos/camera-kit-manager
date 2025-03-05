// Update the ImageHelper class in image_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/rental_item.dart';
import '../../data/item_repository.dart';

class ImageHelper {
  final ImagePicker _imagePicker = ImagePicker();
  final ItemRepository _repository = ItemRepository();

  Future<void> takeItemPicture(RentalItem item, bool isKitOpen) async {
    if (!isKitOpen) {
      throw Exception('Cannot modify items in a closed kit');
    }

    if (kIsWeb) {
      await _handleWebPicture(item);
    } else {
      await _handleMobilePicture(item);
    }
  }

  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    return _imagePicker.pickImage(
      source: source,
      maxWidth: maxWidth ?? 1200,
      maxHeight: maxHeight ?? 1200,
      imageQuality: imageQuality ?? 85,
    );
  }

  // Handle image capture for web platform
  Future<void> _handleWebPicture(RentalItem item) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery, // Using gallery for web
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      // For web platform, use a data URL (in a real app)
      // Here, we're using a placeholder for simplicity
      final updatedItem = RentalItem(
        id: item.id,
        kitId: item.kitId,
        name: item.name,
        dateAdded: item.dateAdded,
        category: item.category,
        notes: item.notes,
        cost: item.cost,
        imageDataUrl:
            'https://example.com/placeholder.jpg', // In a real app, convert to base64
      );

      await _repository.updateRentalItem(updatedItem);
    }
  }

  // Handle image capture for mobile platforms
  Future<void> _handleMobilePicture(RentalItem item) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      // Save image to app directory and get permanent path
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${item.id}.jpg';
      final savedImage = File('${appDir.path}/$fileName');
      await File(image.path).copy(savedImage.path);

      // Update item with image path
      final updatedItem = RentalItem(
        id: item.id,
        kitId: item.kitId,
        name: item.name,
        dateAdded: item.dateAdded,
        category: item.category,
        notes: item.notes,
        cost: item.cost,
        imagePath: savedImage.path,
      );

      await _repository.updateRentalItem(updatedItem);
    }
  }

  // Build image widget based on platform and data
  Widget buildItemImage(RentalItem item) {
    if (kIsWeb && item.imageDataUrl != null) {
      // For web platform with data URL
      return Image.network(
        item.imageDataUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100),
      );
    } else if (!kIsWeb && item.imagePath != null) {
      // For mobile platform with file path
      return Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
