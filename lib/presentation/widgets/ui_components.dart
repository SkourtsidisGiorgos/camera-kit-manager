// lib/presentation/widgets/ui_components.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/kit.dart';
import '../../domain/entities/rental.dart';
import '../../domain/entities/rental_item.dart';
import './common_widgets.dart';

/// A reusable kit list item with configurable actions
class KitListTile extends StatelessWidget {
  final Kit kit;
  final VoidCallback onTap;
  final List<ActionButton> actions;

  const KitListTile({
    super.key,
    required this.kit,
    required this.onTap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: ListTile(
        title: Text(kit.name),
        subtitle: Text('Created: ${DateFormatter.format(kit.dateCreated)}'),
        leading: StatusBadge(isOpen: kit.isOpen),
        trailing: ActionButtons(actions: actions),
      ),
    );
  }

  /// Factory constructor with common actions
  factory KitListTile.withDefaultActions({
    required Kit kit,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onToggleStatus,
    required VoidCallback onDelete,
  }) {
    return KitListTile(
      kit: kit,
      onTap: onTap,
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
    );
  }
}

/// A reusable rental item list tile with configurable actions
class RentalItemTile extends StatelessWidget {
  final RentalItem item;
  final bool isKitOpen;
  final VoidCallback? onTap;
  final List<ActionButton> actions;
  final Widget? itemImage;

  const RentalItemTile({
    super.key,
    required this.item,
    required this.isKitOpen,
    this.onTap,
    required this.actions,
    this.itemImage,
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
            trailing: ActionButtons(actions: actions),
          ),
          if (itemImage != null) itemImage!,
        ],
      ),
    );
  }

  /// Factory constructor with common actions
  factory RentalItemTile.withDefaultActions({
    required RentalItem item,
    required bool isKitOpen,
    VoidCallback? onTap,
    VoidCallback? onTakePicture,
    VoidCallback? onDelete,
    Widget? itemImage,
  }) {
    return RentalItemTile(
      item: item,
      isKitOpen: isKitOpen,
      onTap: onTap,
      itemImage: itemImage,
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
          tooltip: isKitOpen ? AppStrings.delete : 'Cannot delete (Kit closed)',
        ),
      ],
    );
  }
}

/// A reusable rental list tile with configurable actions
class RentalTile extends StatelessWidget {
  final Rental rental;
  final VoidCallback onTap;
  final List<ActionButton> actions;

  const RentalTile({
    super.key,
    required this.rental,
    required this.onTap,
    required this.actions,
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
        leading: _buildLeadingImage(),
        trailing: ActionButtons(actions: actions),
      ),
    );
  }

  Widget _buildLeadingImage() {
    if (rental.imageDataUrl != null || rental.imagePath != null) {
      return CircleAvatar(
        backgroundImage: rental.imageDataUrl != null
            ? NetworkImage(rental.imageDataUrl!)
            : FileImage(File(rental.imagePath!)) as ImageProvider,
      );
    } else {
      return const CircleAvatar(
        child: Icon(Icons.receipt),
      );
    }
  }

  /// Factory constructor with common actions
  factory RentalTile.withDefaultActions({
    required Rental rental,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required Function(Rental) onOpenMaps,
  }) {
    final hasLocation = rental.latitude != null && rental.longitude != null;

    final actions = [
      if (hasLocation)
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
    ];

    return RentalTile(
      rental: rental,
      onTap: onTap,
      actions: actions,
    );
  }
}

/// A reusable detailed info card for rentals
class RentalInfoTile extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onMapTap;

  const RentalInfoTile({
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
            _buildInfoRow(Icons.calendar_today,
                'Start: ${DateFormatter.format(rental.startDate)}'),
            if (rental.endDate != null)
              _buildInfoRow(Icons.event_available,
                  'End: ${DateFormatter.format(rental.endDate!)}'),
            if (rental.address != null) _buildLocationRow(context),
            if (rental.notes != null && rental.notes!.isNotEmpty)
              _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    return InkWell(
      onTap: rental.latitude != null ? onMapTap : null,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rental.address!,
                style: TextStyle(
                  color: rental.latitude != null ? Colors.blue : null,
                  decoration:
                      rental.latitude != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Notes:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(rental.notes!),
      ],
    );
  }
}

/// A reusable form field group for common form patterns
class FormFieldGroup extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry padding;

  const FormFieldGroup({
    super.key,
    required this.title,
    required this.fields,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...fields,
        ],
      ),
    );
  }
}

/// A reusable cost summary card
class CostSummaryTile extends StatelessWidget {
  final double totalCost;
  final String title;

  const CostSummaryTile({
    super.key,
    required this.totalCost,
    this.title = 'Total Equipment Cost:',
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
            Text(
              title,
              style: const TextStyle(
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

/// A reusable date picker row with label
class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Function(BuildContext) onTap;

  const DatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: date != null
          ? Text(DateFormat('MMM d, yyyy').format(date!))
          : const Text('Not set'),
      onTap: () => onTap(context),
    );
  }
}

/// A reusable image picker button with preview
class ImagePickerField extends StatelessWidget {
  final String? imagePath;
  final String? imageDataUrl;
  final VoidCallback onPickImage;
  final String label;
  final double imageHeight;

  const ImagePickerField({
    super.key,
    this.imagePath,
    this.imageDataUrl,
    required this.onPickImage,
    this.label = 'Photo (Optional)',
    this.imageHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (hasImage)
          Container(
            width: double.infinity,
            height: imageHeight,
            margin: const EdgeInsets.only(bottom: 8),
            child: _buildImagePreview(),
          ),
        ElevatedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
        ),
      ],
    );
  }

  bool get hasImage => imagePath != null || imageDataUrl != null;

  Widget _buildImagePreview() {
    if (kIsWeb && imageDataUrl != null) {
      return Image.network(
        imageDataUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100),
      );
    } else if (!kIsWeb && imagePath != null) {
      return Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
      );
    }
    return const Icon(Icons.image, size: 100);
  }
}

/// A reusable location field with map picker
class LocationPickerField extends StatelessWidget {
  final TextEditingController controller;
  final double? latitude;
  final double? longitude;
  final VoidCallback onPickLocation;
  final VoidCallback onGeocodeAddress;

  const LocationPickerField({
    super.key,
    required this.controller,
    this.latitude,
    this.longitude,
    required this.onPickLocation,
    required this.onGeocodeAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Address',
            hintText: 'Enter location address',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: onGeocodeAddress,
              tooltip: 'Find location',
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onPickLocation,
          icon: const Icon(Icons.map),
          label: const Text('Pick Location on Map'),
        ),
        if (latitude != null && longitude != null) ...[
          const SizedBox(height: 8),
          Text(
            'Location: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A reusable kit status indicator with toggle button
class KitStatusIndicator extends StatelessWidget {
  final Kit kit;
  final VoidCallback onToggleStatus;

  const KitStatusIndicator({
    super.key,
    required this.kit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusBadge(isOpen: kit.isOpen),
        const SizedBox(width: 16),
        Text(
          'Status: ${kit.isOpen ? AppStrings.statusOpen : AppStrings.statusClosed}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kit.isOpen ? AppColors.openStatus : AppColors.closedStatus,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onToggleStatus,
          icon: Icon(
            kit.isOpen ? Icons.lock : Icons.lock_open,
            color: kit.isOpen ? AppColors.closedStatus : AppColors.openStatus,
          ),
          label: Text(
            kit.isOpen ? AppStrings.closeKit : AppStrings.reopenKit,
            style: TextStyle(
              color: kit.isOpen ? AppColors.closedStatus : AppColors.openStatus,
            ),
          ),
        ),
      ],
    );
  }
}

/// A generic confirmation dialog
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool isDangerous;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = 'Cancel',
    this.confirmText = 'Confirm',
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDangerous
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Show the dialog and return the result
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmationDialog(
            title: title,
            message: message,
            cancelText: cancelText,
            confirmText: confirmText,
            isDangerous: isDangerous,
          ),
        ) ??
        false;
  }
}

/// Utility method to open a location in maps
Future<void> openMapsLink(
    BuildContext context, double latitude, double longitude) async {
  final url =
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open maps')),
    );
  }
}

/// A class that provides common use cases for image picking
class ImagePickerHelper {
  final ImagePicker _imagePicker = ImagePicker();

  Future<XFile?> pickImage({
    required ImageSource source,
    double maxWidth = 1200,
    double maxHeight = 1200,
    int imageQuality = 85,
  }) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<XFile?> takePicture() async {
    return pickImage(source: ImageSource.camera);
  }

  Future<XFile?> pickFromGallery() async {
    return pickImage(source: ImageSource.gallery);
  }
}
