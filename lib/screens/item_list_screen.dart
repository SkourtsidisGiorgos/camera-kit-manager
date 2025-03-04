import 'package:camera_kit_manager/data/category_repository.dart';
import 'package:camera_kit_manager/screens/add_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/kit.dart';
import '../models/rental_item.dart';
import '../data/item_repository.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';

class ItemListScreen extends StatefulWidget {
  final Kit kit;

  const ItemListScreen({super.key, required this.kit});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final _itemRepository = ItemRepository();
  final _imageHelper = ImageHelper();
  List<RentalItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  Future<void> _refreshItems() async {
    setState(() => _isLoading = true);
    final items = await _itemRepository.getRentalItemsByKitId(widget.kit.id);
    setState(() {
      _items = items..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      _isLoading = false;
    });
  }

  Future<void> _takePicture(RentalItem item) async {
    if (!widget.kit.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cannotModifyClosed)),
      );
      return;
    }

    try {
      await _imageHelper.takeItemPicture(item, widget.kit.isOpen);
      _refreshItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _shareKit() async {
    String content = 'EQUIPMENT KIT: ${widget.kit.name}\n';
    content +=
        'Date Created: ${DateFormat('MMM d, yyyy').format(widget.kit.dateCreated)}\n';
    content +=
        'Status: ${widget.kit.isOpen ? AppStrings.statusOpen : AppStrings.statusClosed}\n\n';
    content += 'EQUIPMENT ITEMS:\n';

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      content += '${i + 1}. ${item.name}\n';
      if (item.category != null) {
        content += '   Category: ${item.category}\n';
      }
      content +=
          '   Added: ${DateFormat('MMM d, yyyy').format(item.dateAdded)}\n';
      content +=
          '   Has Photo: ${(item.imagePath != null || item.imageDataUrl != null) ? 'Yes' : 'No'}\n';
      if (item.notes != null && item.notes!.isNotEmpty) {
        content += '   Notes: ${item.notes}\n';
      }
      content += '\n';
    }

    if (kIsWeb) {
      // For web, we can only share text
      await Share.share(
        content,
        subject: 'Equipment Kit: ${widget.kit.name}',
      );
    } else {
      // For mobile platforms, we can share files
      final appDir = await getApplicationDocumentsDirectory();
      final reportFile = File('${appDir.path}/kit_report_${widget.kit.id}.txt');
      await reportFile.writeAsString(content);

      await Share.share(
        'Equipment Kit: ${widget.kit.name}\n\n$content',
        subject: 'Equipment Kit: ${widget.kit.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareKit,
            tooltip: AppStrings.share,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: widget.kit.isOpen
                ? AppColors.openStatusLight
                : AppColors.closedStatusLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${widget.kit.isOpen ? AppStrings.statusOpen : AppStrings.statusClosed}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.kit.isOpen
                        ? AppColors.openStatus
                        : AppColors.closedStatus,
                  ),
                ),
                Text(
                  'Created: ${DateFormat('MMM d, yyyy').format(widget.kit.dateCreated)}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          AppStrings.noItems,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final formattedDate =
                              DateFormat('MMM d, yyyy').format(item.dateAdded);

                          return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: InkWell(
                                // Make the entire card clickable
                                onTap: widget.kit.isOpen
                                    ? () {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AddItemScreen(
                                                  kitId: widget.kit.id,
                                                  existingItem: item,
                                                ),
                                              ),
                                            )
                                            .then((_) => _refreshItems());
                                      }
                                    : null, // Disable if kit is closed
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      title: Text(item.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Added: $formattedDate'),
                                          if (item.category != null)
                                            Text('Category: ${item.category}'),
                                          if (item.notes != null &&
                                              item.notes!.isNotEmpty)
                                            Text('Notes: ${item.notes}'),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.camera_alt),
                                            onPressed: () => _takePicture(item),
                                            tooltip: AppStrings.takePhoto,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.grey),
                                            onPressed: widget.kit.isOpen
                                                ? () async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                            AppStrings
                                                                .deleteItem),
                                                        content: Text(
                                                            'Are you sure you want to delete "${item.name}"?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(false),
                                                            child: const Text(
                                                                AppStrings
                                                                    .cancel),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(true),
                                                            child: const Text(
                                                                AppStrings
                                                                    .delete,
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red)),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm ?? false) {
                                                      await _itemRepository
                                                          .deleteRentalItem(
                                                              item.id);
                                                      _refreshItems();
                                                    }
                                                  }
                                                : null,
                                            tooltip: widget.kit.isOpen
                                                ? AppStrings.delete
                                                : 'Cannot delete (Kit closed)',
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.imagePath != null ||
                                        item.imageDataUrl != null)
                                      Container(
                                        width: double.infinity,
                                        height: 200,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => Scaffold(
                                                  appBar: AppBar(
                                                    title: Text(item.name),
                                                  ),
                                                  body: Center(
                                                    child: InteractiveViewer(
                                                      panEnabled: true,
                                                      boundaryMargin:
                                                          const EdgeInsets.all(
                                                              20),
                                                      minScale: 0.5,
                                                      maxScale: 4,
                                                      child: _imageHelper
                                                          .buildItemImage(item),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag: 'image-${item.id}',
                                            child: _imageHelper
                                                .buildItemImage(item),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ));
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.kit.isOpen
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) =>
                            AddItemScreen(kitId: widget.kit.id),
                      ),
                    )
                    .then((_) => _refreshItems());
              },
              tooltip: 'Add New Item',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
