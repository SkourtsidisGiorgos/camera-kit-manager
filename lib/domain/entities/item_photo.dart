import 'package:hive_flutter/hive_flutter.dart';

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
