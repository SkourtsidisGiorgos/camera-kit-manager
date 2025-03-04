// Create a new file: lib/models/rental.dart
import 'package:hive_flutter/hive_flutter.dart';

part 'rental.g.dart';

@HiveType(typeId: 3)
class Rental {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime startDate;

  @HiveField(3)
  final DateTime? endDate;

  @HiveField(4)
  final String? address;

  @HiveField(5)
  final double? latitude;

  @HiveField(6)
  final double? longitude;

  @HiveField(7)
  final String? imagePath;

  @HiveField(8)
  final String? imageDataUrl; // For web

  @HiveField(9)
  final String? notes;

  @HiveField(10)
  final List<String> kitIds; // IDs of kits included in this rental

  Rental({
    String? id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.address,
    this.latitude,
    this.longitude,
    this.imagePath,
    this.imageDataUrl,
    this.notes,
    List<String>? kitIds,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        kitIds = kitIds ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
      'imageDataUrl': imageDataUrl,
      'notes': notes,
      'kitIds': kitIds,
    };
  }
}
