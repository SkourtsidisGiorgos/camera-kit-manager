import 'dart:io';
import 'package:camera_kit_manager/core/utils/constants.dart';
import 'package:camera_kit_manager/domain/entities/kit.dart';
import 'package:camera_kit_manager/domain/entities/rental.dart';
import 'package:camera_kit_manager/presentation/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// A reusable rental list item
class RentalListItem extends StatelessWidget {
  final Rental rental;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(Rental) onOpenMaps;

  const RentalListItem({
    super.key,
    required this.rental,
    required this.onTap,
    required this.onDelete,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = DateFormatter.format(rental.startDate);
    final endDate = rental.endDate != null
        ? DateFormatter.format(rental.endDate!)
        : 'Ongoing';

    return AppCard(
      onTap: onTap,
      child: ListTile(
        title: Text(rental.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $startDate'),
            Text('To: $endDate'),
            if (rental.address != null) Text('Location: ${rental.address}'),
          ],
        ),
        leading: rental.imageDataUrl != null || rental.imagePath != null
            ? CircleAvatar(
                backgroundImage: rental.imageDataUrl != null
                    ? NetworkImage(rental.imageDataUrl!)
                    : FileImage(File(rental.imagePath!)) as ImageProvider,
              )
            : const CircleAvatar(
                child: Icon(Icons.receipt),
              ),
        trailing: ActionButtons(
          actions: [
            if (rental.latitude != null && rental.longitude != null)
              ActionButton(
                icon: Icons.map,
                onPressed: () => onOpenMaps(rental),
                color: AppColors.primary,
                tooltip: 'Open in Maps',
              ),
            ActionButton(
              icon: Icons.delete,
              onPressed: onDelete,
              color: Colors.grey,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class RentalKitItem extends StatelessWidget {
  final Kit kit;
  final VoidCallback onViewItems;
  final VoidCallback onRemove;

  const RentalKitItem({
    super.key,
    required this.kit,
    required this.onViewItems,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        title: Text(kit.name),
        subtitle: Text(
          'Status: ${kit.isOpen ? "Open" : "Closed"}',
        ),
        leading: StatusBadge(isOpen: kit.isOpen),
        trailing: ActionButtons(
          actions: [
            ActionButton(
              icon: Icons.visibility,
              onPressed: onViewItems,
              tooltip: 'View Items',
            ),
            ActionButton(
              icon: Icons.remove_circle_outline,
              onPressed: onRemove,
              color: Colors.red,
              tooltip: 'Remove from Rental',
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget for rental information display
class RentalInfoCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onMapTap;

  const RentalInfoCard({
    super.key,
    required this.rental,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rental.imagePath != null || rental.imageDataUrl != null)
              PhotoContainer(
                imagePath: rental.imagePath,
                imageDataUrl: rental.imageDataUrl,
              ),
            Text(
              rental.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Start: ${DateFormatter.format(rental.startDate)}',
                ),
              ],
            ),
            if (rental.endDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event_available, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'End: ${DateFormatter.format(rental.endDate!)}',
                  ),
                ],
              ),
            ],
            if (rental.address != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: rental.latitude != null ? onMapTap : null,
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rental.address!,
                        style: TextStyle(
                          color: rental.latitude != null ? Colors.blue : null,
                          decoration: rental.latitude != null
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (rental.notes != null && rental.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(rental.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A cost summary card for rentals
class CostSummaryCard extends StatelessWidget {
  final double totalCost;

  const CostSummaryCard({
    super.key,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.openStatusLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Equipment Cost:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '\$${totalCost.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
