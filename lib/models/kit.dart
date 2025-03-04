import 'package:hive_flutter/hive_flutter.dart';

part 'kit.g.dart';

@HiveType(typeId: 0)
class Kit {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime dateCreated;

  @HiveField(3)
  final bool isOpen;

  Kit({
    String? id,
    required this.name,
    required this.dateCreated,
    required this.isOpen,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dateCreated': dateCreated.toIso8601String(),
      'isOpen': isOpen,
    };
  }
}
