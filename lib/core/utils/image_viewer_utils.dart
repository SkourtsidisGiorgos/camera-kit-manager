// lib/core/utils/image_viewer_utils.dart

import 'package:camera_kit_manager/domain/entities/item_photo.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/rental_item.dart';
import '../../presentation/screens/common/image_viewer_screen.dart';

/// A utility class for handling image viewing functionality across the app
class ImageViewerUtils {
  /// Open a fullscreen image viewer for an item's photos
  static void openItemPhotos(BuildContext context, RentalItem item,
      {String? title}) {
    // Prepare photos list from the item
    List<ItemPhoto> photos = [];

    // First add photos from the photos collection
    if (item.photos.isNotEmpty) {
      photos.addAll(item.photos);
    }
    // If no photos in collection but legacy photo exists, add it
    else if (item.imagePath != null || item.imageDataUrl != null) {
      photos.add(ItemPhoto(
        id: 'legacy',
        imagePath: item.imagePath,
        imageDataUrl: item.imageDataUrl,
        dateAdded: item.dateAdded,
      ));
    }

    // If there are no photos, show a message
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos available for this item')),
      );
      return;
    }

    // Navigate to the image viewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          photos: photos,
          title: title ?? item.name,
        ),
      ),
    );
  }

  /// Open a specific photo from a list with a given index
  static void openPhotoAtIndex(
      BuildContext context, List<ItemPhoto> photos, int index,
      {String title = 'Photo'}) {
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos available')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          photos: photos,
          initialIndex: index,
          title: title,
        ),
      ),
    );
  }
}
