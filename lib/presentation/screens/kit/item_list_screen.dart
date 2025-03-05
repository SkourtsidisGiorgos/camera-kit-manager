// lib/presentation/screens/kit/item_list_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/kit.dart';
import '../../../domain/entities/rental_item.dart';
import '../../../data/item_repository.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/image_helper.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/common_widgets.dart';
import 'add_item_screen.dart';

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
        'Date Created: ${DateFormatter.format(widget.kit.dateCreated)}\n';
    content +=
        'Status: ${widget.kit.isOpen ? AppStrings.statusOpen : AppStrings.statusClosed}\n\n';
    content += 'EQUIPMENT ITEMS:\n';

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      content += '${i + 1}. ${item.name}\n';
      if (item.category != null) {
        content += '   Category: ${item.category}\n';
      }
      content += '   Added: ${DateFormatter.format(item.dateAdded)}\n';
      content +=
          '   Has Photo: ${(item.imagePath != null || item.imageDataUrl != null) ? 'Yes' : 'No'}\n';
      if (item.notes != null && item.notes!.isNotEmpty) {
        content += '   Notes: ${item.notes}\n';
      }
      content += '\n';
    }

    // Share report
    await Share.share(
      'Equipment Kit: ${widget.kit.name}\n\n$content',
      subject: 'Equipment Kit: ${widget.kit.name}',
    );
  }

  Future<void> _deleteItem(RentalItem item) async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: AppStrings.deleteItem,
      message: 'Are you sure you want to delete "${item.name}"?',
      confirmText: AppStrings.delete,
      isDangerous: true,
    );

    if (confirm) {
      await _itemRepository.deleteRentalItem(item.id);
      _refreshItems();
    }
  }

  void _viewItemImage(RentalItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(item.name),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: 'image-${item.id}',
                child: _imageHelper.buildItemImage(item),
              ),
            ),
          ),
        ),
      ),
    );
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
          // Kit status container
          KitStatusFormatter.build(widget.kit),

          // Items list
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _items.isEmpty
                    ? const EmptyStateView(
                        message: AppStrings.noItems,
                        icon: Icons.inventory_2,
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];

                          // Build image widget if available
                          Widget? itemImage;
                          if (item.imagePath != null ||
                              item.imageDataUrl != null) {
                            itemImage = Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => _viewItemImage(item),
                                child: Hero(
                                  tag: 'image-${item.id}',
                                  child: _imageHelper.buildItemImage(item),
                                ),
                              ),
                            );
                          }

                          return RentalItemTile.withDefaultActions(
                            item: item,
                            isKitOpen: widget.kit.isOpen,
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) => AddItemScreen(
                                        kitId: widget.kit.id,
                                        existingItem: item,
                                      ),
                                    ),
                                  )
                                  .then((_) => _refreshItems());
                            },
                            onTakePicture: () => _takePicture(item),
                            onDelete: () => _deleteItem(item),
                            itemImage: itemImage,
                          );
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
