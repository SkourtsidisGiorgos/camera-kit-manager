// lib/widgets/common_widgets.dart

import 'dart:io';
import 'package:camera_kit_manager/core/utils/constants.dart';
import 'package:camera_kit_manager/domain/entities/kit.dart';
import 'package:camera_kit_manager/domain/entities/rental_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      color: color,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

/// A badge showing open/closed status
class StatusBadge extends StatelessWidget {
  final bool isOpen;
  final bool showIcon;
  final double size;

  const StatusBadge({
    super.key,
    required this.isOpen,
    this.showIcon = true,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: isOpen ? AppColors.openStatus : AppColors.closedStatus,
      child: showIcon
          ? Icon(
              isOpen ? Icons.lock_open : Icons.lock,
              color: Colors.white,
              size: size * 0.6,
            )
          : null,
    );
  }
}

/// A widget for displaying status indicators with text
class StatusContainer extends StatelessWidget {
  final bool isOpen;
  final String? dateText;

  const StatusContainer({
    super.key,
    required this.isOpen,
    this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isOpen ? AppColors.openStatusLight : AppColors.closedStatusLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Status: ${isOpen ? AppStrings.statusOpen : AppStrings.statusClosed}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOpen ? AppColors.openStatus : AppColors.closedStatus,
            ),
          ),
          if (dateText != null)
            Text(
              dateText!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

/// A widget for displaying photos with proper handling for web/mobile
class PhotoContainer extends StatelessWidget {
  final String? imagePath;
  final String? imageDataUrl;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;

  const PhotoContainer({
    super.key,
    this.imagePath,
    this.imageDataUrl,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = const Icon(Icons.image_not_supported, size: 100);

    if (kIsWeb && imageDataUrl != null) {
      imageWidget = Image.network(
        imageDataUrl!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100),
      );
    } else if (!kIsWeb && imagePath != null) {
      imageWidget = Image.file(
        File(imagePath!),
        fit: fit,
      );
    }

    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: imageWidget,
      ),
    );
  }
}

/// A reusable item photo widget that works with RentalItem model
class ItemPhotoWidget extends StatelessWidget {
  final RentalItem item;
  final double height;
  final VoidCallback? onTap;

  const ItemPhotoWidget({
    super.key,
    required this.item,
    this.height = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PhotoContainer(
      imagePath: item.imagePath,
      imageDataUrl: item.imageDataUrl,
      height: height,
      onTap: onTap,
    );
  }
}

class ActionButtons extends StatelessWidget {
  final List<ActionButton> actions;

  const ActionButtons({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const ActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class AppFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final Widget? suffix;
  final bool enabled;
  final String? Function(String?)? validator;

  const AppFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: suffix,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator ??
          (required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter $label';
                  }
                  return null;
                }
              : null),
    );
  }
}

/// A loading view with progress indicator
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// A view for empty states with customizable message
class EmptyStateView extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyStateView({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable confirmation dialog
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelText = 'Cancel',
  String confirmText = 'Delete',
  bool isDangerous = true,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
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
        ),
      ) ??
      false;
}

/// A date formatter for consistent date display
class DateFormatter {
  static String format(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatWithTime(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }
}

class KitStatusFormatter {
  static Widget build(Kit kit) {
    return StatusContainer(
      isOpen: kit.isOpen,
      dateText: 'Created: ${DateFormatter.format(kit.dateCreated)}',
    );
  }
}

/// A reusable section header
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppListView extends StatelessWidget {
  final List<Widget> children;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AppListView({
    super.key,
    required this.children,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: children,
    );
  }
}
