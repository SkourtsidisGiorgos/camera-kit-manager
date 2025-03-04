# Hive Adapter Generation Guide

Since we've split our model classes into separate files and we're using Hive for persistence, we need to generate the adapter code. Here's how to set it up:

## Step 1: Add build_runner and hive_generator to your pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  intl: ^0.18.0
  image_picker: ^0.8.7
  path_provider: ^2.0.15
  share_plus: ^6.3.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  build_runner: ^2.3.3
  hive_generator: ^2.0.0
```

## Step 2: Modify Model Files to Support Code Generation

For each model file (kit.dart, rental_item.dart, equipment_category.dart), you need to add a part directive at the top to connect the generated code.

For example, in `kit.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';

part 'kit.g.dart';  // Add this line

@HiveType(typeId: 0)
class Kit {
  // Class implementation
}
```

## Step 3: Run Code Generation Command

Run the following command in your terminal to generate the adapter code:

```bash
flutter pub run build_runner build
```

This will create the .g.dart files that contain the adapter implementations.

## Step 4: Add EquipmentCategory Adapter

In models/equipment_category.dart, add the adapter implementation:

```dart
// Hive adapter for EquipmentCategory
class EquipmentCategoryAdapter extends TypeAdapter<EquipmentCategory> {
  @override
  final int typeId = 2;

  @override
  EquipmentCategory read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final itemsLength = reader.readInt();
    final predefinedItems = <String>[];
    
    for (var i = 0; i < itemsLength; i++) {
      predefinedItems.add(reader.readString());
    }

    return EquipmentCategory(
      id: id,
      name: name,
      predefinedItems: predefinedItems,
    );
  }

  @override
  void write(BinaryWriter writer, EquipmentCategory obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.predefinedItems.length);
    for (var item in obj.predefinedItems) {
      writer.writeString(item);
    }
  }
}
```

For now, you can manually add the adapter classes to each model file until you set up code generation.