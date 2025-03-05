import 'package:hive_flutter/hive_flutter.dart';

part 'rental_item.g.dart';

@HiveType(typeId: 1)
class RentalItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String kitId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final DateTime dateAdded;

  @HiveField(4)
  final String? imagePath; // Legacy support for single image

  @HiveField(5)
  final String? imageDataUrl; // Legacy support for web platform

  @HiveField(6)
  final String? category;

  @HiveField(7)
  final String? notes;

  @HiveField(8)
  final double? cost;

  @HiveField(9)
  final List<ItemPhoto> photos; // Multiple photos support

  RentalItem({
    String? id,
    required this.kitId,
    required this.name,
    required this.dateAdded,
    this.imagePath,
    this.imageDataUrl,
    this.category,
    this.notes,
    this.cost,
    List<ItemPhoto>? photos,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        photos = photos ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kitId': kitId,
      'name': name,
      'dateAdded': dateAdded.toIso8601String(),
      'imagePath': imagePath,
      'imageDataUrl': imageDataUrl,
      'category': category,
      'notes': notes,
      'cost': cost,
      'photos': photos.map((photo) => photo.toMap()).toList(),
    };
  }

  // Helper method to check if item has any photos
  bool get hasPhotos =>
      photos.isNotEmpty || imagePath != null || imageDataUrl != null;

  // Helper method to get primary photo (first photo or legacy photo)
  ItemPhoto? get primaryPhoto {
    if (photos.isNotEmpty) {
      return photos.first;
    } else if (imagePath != null || imageDataUrl != null) {
      return ItemPhoto(
        id: 'legacy',
        imagePath: imagePath,
        imageDataUrl: imageDataUrl,
        dateAdded: dateAdded,
      );
    }
    return null;
  }
}

@HiveType(typeId: 4) // Using a new typeId for the new class
class ItemPhoto {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? imagePath;

  @HiveField(2)
  final String? imageDataUrl;

  @HiveField(3)
  final DateTime dateAdded;

  @HiveField(4)
  final String? caption;

  ItemPhoto({
    String? id,
    this.imagePath,
    this.imageDataUrl,
    required this.dateAdded,
    this.caption,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'imageDataUrl': imageDataUrl,
      'dateAdded': dateAdded.toIso8601String(),
      'caption': caption,
    };
  }
}
