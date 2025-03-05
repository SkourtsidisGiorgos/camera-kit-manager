import 'dart:io';
import 'package:camera_kit_manager/core/utils/image_viewer_utils.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/kit.dart';
import '../../../domain/entities/rental_item.dart';
import '../../../domain/entities/equipment_category.dart';
import '../../../data/item_repository.dart';
import '../../../data/category_repository.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/image_helper.dart';
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
  final _categoryRepository = CategoryRepository();
  final _imageHelper = ImageHelper();
  final _searchController = TextEditingController();

  List<RentalItem> _allItems = [];
  List<RentalItem> _filteredItems = [];
  List<EquipmentCategory> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load items
      final items = await _itemRepository.getRentalItemsByKitId(widget.kit.id);

      // Load categories
      final categories = await _categoryRepository.getAllCategories();

      setState(() {
        _allItems = items..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        _filteredItems = List.from(_allItems);
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterItemsByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  void _searchItems(String query) {
    setState(() {
      _applyFilters();
    });
  }

  void _applyFilters() {
    final String searchQuery = _searchController.text.toLowerCase();

    setState(() {
      _filteredItems = _allItems.where((item) {
        // Apply category filter if selected
        if (_selectedCategory != null && item.category != _selectedCategory) {
          return false;
        }

        // Apply search filter if query exists
        if (searchQuery.isNotEmpty) {
          final name = item.name.toLowerCase();
          final notes = item.notes?.toLowerCase() ?? '';
          final category = item.category?.toLowerCase() ?? '';

          return name.contains(searchQuery) ||
              notes.contains(searchQuery) ||
              category.contains(searchQuery);
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      _filteredItems = List.from(_allItems);
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
      _loadData();
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

    for (var i = 0; i < _filteredItems.length; i++) {
      final item = _filteredItems[i];
      content += '${i + 1}. ${item.name}\n';
      if (item.category != null) {
        content += '   Category: ${item.category}\n';
      }
      content += '   Added: ${DateFormatter.format(item.dateAdded)}\n';
      if (item.notes != null && item.notes!.isNotEmpty) {
        content += '   Notes: ${item.notes}\n';
      }
      if (item.cost != null) {
        content += '   Cost: \$${item.cost!.toStringAsFixed(2)}\n';
      }
      content += '\n';
    }

    // Share report
    await Share.share(
      content,
      subject: 'Equipment Kit: ${widget.kit.name}',
    );
  }

  Future<void> _deleteItem(RentalItem item) async {
    final confirm = await showConfirmationDialog(
      context: context,
      title: AppStrings.deleteItem,
      content: 'Are you sure you want to delete "${item.name}"?',
      confirmText: AppStrings.delete,
    );

    if (confirm) {
      await _itemRepository.deleteRentalItem(item.id);
      _loadData();
    }
  }

  void _editItem(RentalItem item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AddItemScreen(
              kitId: widget.kit.id,
              existingItem: item,
            ),
          ),
        )
        .then((_) => _loadData());
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

          // Search and Filter section
          _buildSearchAndFilter(),

          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? const Center(
                        child: Text("No items match your search criteria"),
                      )
                    : ListView.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return _buildItemCard(item);
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
                    .then((_) => _loadData());
              },
              tooltip: 'Add New Item',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchItems('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _searchItems,
          ),

          const SizedBox(height: 8),

          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Filter: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),

                // All categories chip
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) {
                      _filterItemsByCategory(null);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Category chips
                ..._categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: _selectedCategory == category.name,
                      onSelected: (selected) {
                        if (selected) {
                          _filterItemsByCategory(category.name);
                        } else {
                          _filterItemsByCategory(null);
                        }
                      },
                    ),
                  );
                }),

                // Clear filters button
                if (_selectedCategory != null ||
                    _searchController.text.isNotEmpty)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(RentalItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _editItem(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail (smaller size)
              _buildItemThumbnail(item),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (item.category != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.category!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (item.cost != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '\$${item.cost!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.kit.isOpen)
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _takePicture(item),
                      tooltip: 'Take Photo',
                    ),
                  if (widget.kit.isOpen)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteItem(item),
                      tooltip: 'Delete Item',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(RentalItem item) {
    // Size reduced to 50px for smaller thumbnails
    const double size = 90;

    // Check if item has a photo
    final hasPhoto = item.imagePath != null ||
        item.imageDataUrl != null ||
        (item.photos.isNotEmpty);

    if (!hasPhoto) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.photo_camera,
            color: Colors.grey.shade400, size: size * 0.5),
      );
    }

    return GestureDetector(
      onTap: () => ImageViewerUtils.openItemPhotos(context, item),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Same image loading code as you had before
            Builder(builder: (context) {
              try {
                if (item.photos.isNotEmpty) {
                  // Use the first photo from the photos list
                  final photo = item.photos.first;
                  if (photo.imagePath != null) {
                    return Image.file(
                      File(photo.imagePath!),
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error loading image: $error');
                        return Icon(Icons.broken_image,
                            color: Colors.grey.shade400, size: size * 0.5);
                      },
                    );
                  } else if (photo.imageDataUrl != null) {
                    return Image.network(
                      photo.imageDataUrl!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Error loading image: $error');
                        return Icon(Icons.broken_image,
                            color: Colors.grey.shade400, size: size * 0.5);
                      },
                    );
                  }
                } else if (item.imagePath != null) {
                  // Legacy image path support
                  return Image.file(
                    File(item.imagePath!),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading image: $error');
                      return Icon(Icons.broken_image,
                          color: Colors.grey.shade400, size: size * 0.5);
                    },
                  );
                } else if (item.imageDataUrl != null) {
                  // Legacy image URL support
                  return Image.network(
                    item.imageDataUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading image: $error');
                      return Icon(Icons.broken_image,
                          color: Colors.grey.shade400, size: size * 0.5);
                    },
                  );
                }

                // Fallback if no image could be loaded
                return Icon(Icons.photo,
                    color: Colors.grey.shade400, size: size * 0.5);
              } catch (e) {
                debugPrint('Error in thumbnail builder: $e');
                return Icon(Icons.error,
                    color: Colors.grey.shade400, size: size * 0.5);
              }
            }),

            // Add a small indicator if there are multiple photos
            if (item.photos.length > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
