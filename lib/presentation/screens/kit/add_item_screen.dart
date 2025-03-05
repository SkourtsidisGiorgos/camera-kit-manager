import 'dart:io';
import 'dart:async';
import 'package:camera_kit_manager/core/utils/image_viewer_utils.dart';
import 'package:camera_kit_manager/presentation/screens/common/image_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/entities/rental_item.dart';
import '../../../domain/entities/equipment_category.dart';
import '../../../data/item_repository.dart';
import '../../../data/category_repository.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/image_helper.dart';

class AddItemScreen extends StatefulWidget {
  final String kitId;
  final RentalItem? existingItem; // For editing existing item

  const AddItemScreen({
    super.key,
    required this.kitId,
    this.existingItem,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController = TextEditingController();
  final _itemRepository = ItemRepository();
  final _categoryRepository = CategoryRepository();
  final _imageHelper = ImageHelper();
  final _debouncer = Debouncer(milliseconds: 500);
  final _MAX_PHOTOS = 6;

  List<EquipmentCategory> _categories = [];
  List<String> _predefinedItems = [];
  String? _selectedCategory;
  bool _isCustomItem = true;
  bool _isLoading = true;
  bool _isSaving = false;

  // Legacy photo support
  String? _imagePath;
  String? _imageDataUrl;

  // Multiple photos
  List<ItemPhoto> _photos = [];

  // Current item being edited
  RentalItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // If editing an existing item
    if (widget.existingItem != null) {
      _itemNameController.text = widget.existingItem!.name;
      _selectedCategory = widget.existingItem!.category;
      if (widget.existingItem!.notes != null) {
        _notesController.text = widget.existingItem!.notes!;
      }
      if (widget.existingItem!.cost != null) {
        _costController.text = widget.existingItem!.cost!.toString();
      }
      _imagePath = widget.existingItem!.imagePath;
      _imageDataUrl = widget.existingItem!.imageDataUrl;
      _photos = List.from(widget.existingItem!.photos);
      _currentItem = widget.existingItem;
    }

    // Add listeners for auto-save
    _itemNameController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _costController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    // Remove listeners
    _itemNameController.removeListener(_onFieldChanged);
    _notesController.removeListener(_onFieldChanged);
    _costController.removeListener(_onFieldChanged);

    // Dispose controllers
    _itemNameController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // Auto-save changes after a short delay
    if (_formKey.currentState?.validate() ?? false) {
      _debouncer.run(() {
        _saveItem();
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    await _categoryRepository.initDefaultCategoriesIfEmpty();
    final categories = await _categoryRepository.getAllCategories();

    setState(() {
      _categories = categories;
      _isLoading = false;

      if (widget.existingItem?.category != null) {
        _onCategoryChanged(widget.existingItem!.category!);
      }
    });
  }

  void _onCategoryChanged(String? categoryName) {
    setState(() {
      _selectedCategory = categoryName;

      if (categoryName != null) {
        // Find the selected category and load its predefined items
        final selectedCategory = _categories.firstWhere(
          (category) => category.name == categoryName,
          orElse: () => EquipmentCategory(name: '', predefinedItems: []),
        );

        _predefinedItems = selectedCategory.predefinedItems;

        // Reset custom item flag when changing categories
        _isCustomItem = true;
      } else {
        _predefinedItems = [];
        _isCustomItem = true;
      }

      // Auto-save on category change
      _onFieldChanged();
    });
  }

  void _onPredefinedItemSelected(String itemName) {
    setState(() {
      _itemNameController.text = itemName;
      _isCustomItem = false;

      // Auto-save when selecting predefined item
      _onFieldChanged();
    });
  }

  Future<void> _takePicture() async {
    try {
      if (_photos.length >= _MAX_PHOTOS) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Maximum of $_MAX_PHOTOS photos allowed per item')),
        );
        return;
      }

      final XFile? image = await _imageHelper.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            // For web, use placeholder data URL
            final newPhoto = ItemPhoto(
              dateAdded: DateTime.now(),
              imageDataUrl: 'https://example.com/placeholder.jpg',
            );
            _photos.add(newPhoto);
          } else {
            // For mobile, store temporary path (will be copied to permanent location on save)
            final newPhoto = ItemPhoto(
              dateAdded: DateTime.now(),
              imagePath: image.path,
            );
            _photos.add(newPhoto);
          }
        });

        // Auto-save after adding a photo
        _saveItem();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickPicture() async {
    try {
      if (_photos.length >= _MAX_PHOTOS) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Maximum of $_MAX_PHOTOS photos allowed per item')),
        );
        return;
      }

      final XFile? image = await _imageHelper.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            // For web, use placeholder data URL
            final newPhoto = ItemPhoto(
              dateAdded: DateTime.now(),
              imageDataUrl: 'https://example.com/placeholder.jpg',
            );
            _photos.add(newPhoto);
          } else {
            // For mobile, store temporary path (will be copied to permanent location on save)
            final newPhoto = ItemPhoto(
              dateAdded: DateTime.now(),
              imagePath: image.path,
            );
            _photos.add(newPhoto);
          }
        });

        // Auto-save after adding a photo
        _saveItem();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking picture: ${e.toString()}')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);

      // Auto-save after removing a photo
      _saveItem();
    });
  }

  Future<void> _saveItem() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Parse cost
      double? cost;
      if (_costController.text.isNotEmpty) {
        cost = double.tryParse(_costController.text);
      }

      // Process photos - First make a copy of the photos list
      List<ItemPhoto> processedPhotos = List.from(_photos);

      // If not on web, save images to permanent location
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();

        // Process each photo
        for (int i = 0; i < processedPhotos.length; i++) {
          final photo = processedPhotos[i];

          // Skip photos that already have a permanent path or photos from existing item
          if (photo.imagePath != null &&
              (widget.existingItem == null ||
                  !widget.existingItem!.photos
                      .any((p) => p.imagePath == photo.imagePath))) {
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_${i}_${widget.kitId}.jpg';
            final savedImage = File('${appDir.path}/$fileName');
            await File(photo.imagePath!).copy(savedImage.path);

            // Replace with permanent path
            processedPhotos[i] = ItemPhoto(
              id: photo.id,
              dateAdded: photo.dateAdded,
              imagePath: savedImage.path,
              caption: photo.caption,
            );
          }
        }
      }

      // Create the item
      final item = RentalItem(
        id: widget.existingItem?.id,
        kitId: widget.kitId,
        name: _itemNameController.text,
        dateAdded: widget.existingItem?.dateAdded ?? DateTime.now(),
        imagePath: _imagePath ?? widget.existingItem?.imagePath,
        imageDataUrl: _imageDataUrl ?? widget.existingItem?.imageDataUrl,
        category: _selectedCategory,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        cost: cost,
        photos: processedPhotos,
      );

      await _itemRepository.saveRentalItem(item);
      _currentItem = item;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null
            ? AppStrings.addItem
            : 'Edit ${widget.existingItem!.name}'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: AppStrings.category,
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedCategory,
                      hint: const Text(AppStrings.selectCategory),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.name,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: _onCategoryChanged,
                    ),

                    const SizedBox(height: 16),

                    // Predefined Items if a category is selected
                    if (_selectedCategory != null &&
                        _predefinedItems.isNotEmpty) ...[
                      const Text(
                        AppStrings.selectFromPredefined,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _predefinedItems.map((item) {
                          return ChoiceChip(
                            label: Text(item),
                            selected: !_isCustomItem &&
                                _itemNameController.text == item,
                            onSelected: (selected) {
                              if (selected) {
                                _onPredefinedItemSelected(item);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Custom Item Option
                      CheckboxListTile(
                        title: const Text(AppStrings.customItem),
                        value: _isCustomItem,
                        onChanged: (value) {
                          setState(() {
                            _isCustomItem = value ?? true;
                            if (_isCustomItem) {
                              _itemNameController.clear();
                            }
                          });
                          _onFieldChanged();
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Item Name TextField
                    TextFormField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.itemName,
                        hintText: AppStrings.itemNameHint,
                        border: OutlineInputBorder(),
                      ),
                      enabled: _isCustomItem || _selectedCategory == null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.itemNameValidator;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Notes TextField
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.notes,
                        hintText: AppStrings.notesHint,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    // Cost TextField
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Cost (Optional)',
                        hintText: 'Item cost',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),

                    const SizedBox(height: 16),

                    // Photo Section
                    Text(
                      'Item Photos (Max $_MAX_PHOTOS)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Photo Grid
                    if (_photos.isNotEmpty ||
                        _imagePath != null ||
                        _imageDataUrl != null)
                      _buildPhotoGrid(),

                    const SizedBox(height: 16),

                    // Photo buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _photos.length < _MAX_PHOTOS
                                ? _takePicture
                                : null,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _photos.length < _MAX_PHOTOS
                                ? _pickPicture
                                : null,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoGrid() {
    // Combine legacy photo with new photos if needed
    List<Widget> photoWidgets = [];

    // Add legacy photo if exists and no new photos
    if ((_imagePath != null || _imageDataUrl != null) && _photos.isEmpty) {
      final legacyPhoto = ItemPhoto(
        id: 'legacy',
        imagePath: _imagePath,
        imageDataUrl: _imageDataUrl,
        dateAdded: DateTime.now(),
      );

      photoWidgets.add(_buildPhotoCard(legacyPhoto, 0));
    }

    // Add new photos
    for (int i = 0; i < _photos.length; i++) {
      photoWidgets.add(_buildPhotoCard(_photos[i], i));
    }

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: photoWidgets,
    );
  }

  Widget _buildPhotoCard(ItemPhoto photo, int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            // Create photo list for the gallery
            List<ItemPhoto> photos =
                _photos.isEmpty && (_imagePath != null || _imageDataUrl != null)
                    ? [
                        ItemPhoto(
                          id: 'legacy',
                          imagePath: _imagePath,
                          imageDataUrl: _imageDataUrl,
                          dateAdded: DateTime.now(),
                        )
                      ]
                    : List.from(_photos);

            ImageViewerUtils.openPhotoAtIndex(context, photos, index,
                title: _itemNameController.text.isNotEmpty
                    ? _itemNameController.text
                    : 'Item Photo');
          },
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Builder(
                builder: (context) {
                  try {
                    if (photo.imagePath != null) {
                      return Image.file(
                        File(photo.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                      );
                    } else if (photo.imageDataUrl != null) {
                      return Image.network(
                        photo.imageDataUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                      );
                    } else {
                      return const Icon(Icons.image);
                    }
                  } catch (e) {
                    return const Icon(Icons.error);
                  }
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () {
                if (photo.id == 'legacy') {
                  setState(() {
                    _imagePath = null;
                    _imageDataUrl = null;
                    _saveItem();
                  });
                } else {
                  _removePhoto(index);
                }
              },
            ),
          ),
        ),
        // Optional: add a zoom indicator to help users understand the photo is tappable
        // Positioned(
        //   bottom: 5,
        //   left: 5,
        //   child: Container(
        //     padding: const EdgeInsets.all(4),
        //     decoration: BoxDecoration(
        //       color: Colors.black.withOpacity(0.6),
        //       borderRadius: BorderRadius.circular(4),
        //     ),
        //     child: const Icon(
        //       Icons.zoom_in,
        //       color: Colors.white,
        //       size: 16,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

// Debouncer class for auto-save
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
