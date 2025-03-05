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
  final String? imagePath;

  @HiveField(5)
  final String? imageDataUrl; // For web platform

  @HiveField(6)
  final String? category; // Added category field

  @HiveField(7)
  final String? notes; // Added notes field

  @HiveField(8)
  final double? cost; // Added cost field

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
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

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
    };
  }
}
