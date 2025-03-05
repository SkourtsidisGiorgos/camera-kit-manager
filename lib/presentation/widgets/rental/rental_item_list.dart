import 'package:camera_kit_manager/core/utils/constants.dart';
import 'package:camera_kit_manager/domain/entities/rental_item.dart';
import 'package:camera_kit_manager/presentation/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// A reusable rental item list item
class RentalItemListItem extends StatelessWidget {
  final RentalItem item;
  final bool isKitOpen;
  final VoidCallback? onTap;
  final VoidCallback? onTakePicture;
  final VoidCallback? onDelete;

  const RentalItemListItem({
    super.key,
    required this.item,
    required this.isKitOpen,
    this.onTap,
    this.onTakePicture,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormatter.format(item.dateAdded);

    return AppCard(
      onTap: isKitOpen ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Added: $formattedDate'),
                if (item.category != null) Text('Category: ${item.category}'),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text('Notes: ${item.notes}'),
                if (item.cost != null)
                  Text('Cost: \$${item.cost!.toStringAsFixed(2)}'),
              ],
            ),
            trailing: ActionButtons(
              actions: [
                ActionButton(
                  icon: Icons.camera_alt,
                  onPressed: isKitOpen ? onTakePicture : null,
                  tooltip: AppStrings.takePhoto,
                ),
                ActionButton(
                  icon: Icons.delete,
                  onPressed: isKitOpen ? onDelete : null,
                  color: Colors.grey,
                  tooltip: isKitOpen
                      ? AppStrings.delete
                      : 'Cannot delete (Kit closed)',
                ),
              ],
            ),
          ),
          if (item.imagePath != null || item.imageDataUrl != null)
            ItemPhotoWidget(
              item: item,
              onTap: () {
                // TODO: Photo preview functionality would go here
              },
            ),
        ],
      ),
    );
  }
}
