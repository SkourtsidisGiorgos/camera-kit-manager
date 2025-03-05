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

  // Take a new photo for an item
  Future<void> takeItemPicture(RentalItem item, bool isKitOpen) async {
    if (!isKitOpen) {
      throw Exception('Cannot modify items in a closed kit');
    }

    final XFile? image = await pickImage(source: ImageSource.camera);
    if (image != null) {
      await _addPhotoToItem(item, image);
    }
  }

  // Add a photo from gallery
  Future<void> pickItemPicture(RentalItem item, bool isKitOpen) async {
    if (!isKitOpen) {
      throw Exception('Cannot modify items in a closed kit');
    }

    final XFile? image = await pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _addPhotoToItem(item, image);
    }
  }

  // Pick image from camera or gallery
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

  // Save photo and update the item
  Future<void> _addPhotoToItem(RentalItem item, XFile image) async {
    // Check if already at max photos (3)
    if (item.photos.length >= 3) {
      throw Exception('Maximum of 3 photos allowed per item');
    }

    if (kIsWeb) {
      // For web platform
      final newPhoto = ItemPhoto(
        dateAdded: DateTime.now(),
        imageDataUrl:
            'https://example.com/placeholder.jpg', // Placeholder for web
      );

      final updatedPhotos = [...item.photos, newPhoto];
      await _updateItemWithPhotos(item, updatedPhotos);
    } else {
      // For mobile platforms
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${item.id}.jpg';
      final savedImage = File('${appDir.path}/$fileName');
      await File(image.path).copy(savedImage.path);

      final newPhoto = ItemPhoto(
        dateAdded: DateTime.now(),
        imagePath: savedImage.path,
      );

      final updatedPhotos = [...item.photos, newPhoto];
      await _updateItemWithPhotos(item, updatedPhotos);
    }
  }

  // Update item with new photos
  Future<void> _updateItemWithPhotos(
      RentalItem item, List<ItemPhoto> photos) async {
    final updatedItem = RentalItem(
      id: item.id,
      kitId: item.kitId,
      name: item.name,
      dateAdded: item.dateAdded,
      imagePath: item.imagePath, // Keep for backward compatibility
      imageDataUrl: item.imageDataUrl, // Keep for backward compatibility
      category: item.category,
      notes: item.notes,
      cost: item.cost,
      photos: photos,
    );

    await _repository.updateRentalItem(updatedItem);
  }

  // Delete a photo from an item
  Future<void> deletePhoto(RentalItem item, ItemPhoto photo) async {
    final updatedPhotos = item.photos.where((p) => p.id != photo.id).toList();
    await _updateItemWithPhotos(item, updatedPhotos);

    // Delete the actual file
    if (!kIsWeb && photo.imagePath != null) {
      try {
        final file = File(photo.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting photo file: $e');
      }
    }
  }

  // Build image widget for a photo
  Widget buildPhotoImage(ItemPhoto photo, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb && photo.imageDataUrl != null) {
      return Image.network(
        photo.imageDataUrl!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100),
      );
    } else if (!kIsWeb && photo.imagePath != null) {
      return Image.file(
        File(photo.imagePath!),
        fit: fit,
      );
    } else {
      return const Icon(Icons.image_not_supported, size: 100);
    }
  }

  // Build item image (primary or legacy)
  Widget buildItemImage(RentalItem item, {BoxFit fit = BoxFit.cover}) {
    final primaryPhoto = item.primaryPhoto;

    if (primaryPhoto != null) {
      return buildPhotoImage(primaryPhoto, fit: fit);
    } else {
      return const Icon(Icons.image_not_supported, size: 100);
    }
  }

  // Build thumbnail for item
  Widget buildItemThumbnail(RentalItem item, {double size = 80}) {
    if (!item.hasPhotos) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.photo_camera,
            color: Colors.grey.shade400, size: size * 0.5),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: buildItemImage(item),
    );
  }
}
