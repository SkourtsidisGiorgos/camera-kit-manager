import 'package:hive_flutter/hive_flutter.dart';

part 'equipment_category.g.dart';

@HiveType(typeId: 2)
class EquipmentCategory {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> predefinedItems;

  EquipmentCategory({
    String? id,
    required this.name,
    required this.predefinedItems,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class EquipmentCategories {
  static final List<EquipmentCategory> defaultCategories = [
    EquipmentCategory(
      name: 'Camera Bodies',
      predefinedItems: [
        'ARRI Alexa Mini',
        'RED DSMC2',
        'Sony FX9',
        'Canon C300 Mark III',
        'Blackmagic URSA Mini Pro',
        'Panasonic Varicam LT',
      ],
    ),
    EquipmentCategory(
      name: 'Lenses',
      predefinedItems: [
        'Canon CN-E 24mm T1.5',
        'Zeiss CP.3 35mm T2.1',
        'ARRI/Zeiss Master Prime 50mm T1.3',
        'Cooke S4/i 75mm T2.0',
        'Angenieux Optimo 28-76mm T2.6',
        'Fujinon Cabrio 19-90mm T2.9',
      ],
    ),
    EquipmentCategory(
      name: 'Support',
      predefinedItems: [
        'Sachtler Flowtech 75 Tripod',
        'Connor 2575D Fluid Head',
        'Easy Rig Cinema 3',
        'DJI Ronin 2',
        'Tilta Nucleus-M Follow Focus',
        'Wooden Camera Baseplate',
      ],
    ),
    EquipmentCategory(
      name: 'Monitoring',
      predefinedItems: [
        'SmallHD 702 Bright',
        'Atomos Ninja V',
        'Teradek Bolt 4K 750',
        'TVLogic LUM-171G',
        'Convergent Design Odyssey 7Q+',
      ],
    ),
    EquipmentCategory(
      name: 'Power',
      predefinedItems: [
        'Anton Bauer CINE 150 Battery',
        'Core SWX Hypercore 98',
        'D-Tap Splitter',
        'V-Mount Plate',
        'AC Power Adapter',
      ],
    ),
    EquipmentCategory(
      name: 'Media',
      predefinedItems: [
        'RED MINI-MAG 480GB',
        'CFast 2.0 256GB',
        'SSD 1TB',
        'SD Card 128GB',
        'Card Reader',
      ],
    ),
    EquipmentCategory(
      name: 'Grip',
      predefinedItems: [
        'C-Stand',
        'Apple Box Set',
        'Sand Bags',
        'Clamps (Various)',
        'Flags and Nets',
      ],
    ),
    EquipmentCategory(
      name: 'Audio',
      predefinedItems: [
        'Sennheiser MKH 416',
        'Rode NTG4+',
        'Sound Devices MixPre-6 II',
        'Zoom H6',
        'Lavalier Microphone Kit',
      ],
    ),
  ];
}
