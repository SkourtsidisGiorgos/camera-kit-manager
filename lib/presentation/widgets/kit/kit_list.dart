import 'package:camera_kit_manager/core/utils/constants.dart';
import 'package:camera_kit_manager/domain/entities/kit.dart';
import 'package:camera_kit_manager/presentation/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

class KitListItem extends StatelessWidget {
  final Kit kit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const KitListItem({
    super.key,
    required this.kit,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: ListTile(
        title: Text(kit.name),
        subtitle: Text('Created: ${DateFormatter.format(kit.dateCreated)}'),
        leading: StatusBadge(isOpen: kit.isOpen),
        trailing: ActionButtons(
          actions: [
            ActionButton(
              icon: Icons.edit,
              onPressed: onEdit,
              tooltip: 'Edit Kit',
            ),
            ActionButton(
              icon: kit.isOpen ? Icons.lock : Icons.lock_open,
              onPressed: onToggleStatus,
              color: kit.isOpen ? AppColors.closedStatus : AppColors.openStatus,
              tooltip: kit.isOpen ? AppStrings.closeKit : AppStrings.reopenKit,
            ),
            ActionButton(
              icon: Icons.delete,
              onPressed: onDelete,
              color: Colors.grey,
              tooltip: AppStrings.delete,
            ),
          ],
        ),
      ),
    );
  }
}
