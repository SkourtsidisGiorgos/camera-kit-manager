import 'dart:io';

import 'package:camera_kit_manager/data/category_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/entities/rental_item.dart';
import '../../../domain/entities/equipment_category.dart';
import '../../../data/item_repository.dart';
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
  final _costController = TextEditingController(); // Added cost controller
  final _item_repository = ItemRepository();
  final _category_repository = CategoryRepository();
  final _imageHelper = ImageHelper(); // Added ImageHelper

  List<EquipmentCategory> _categories = [];
  List<String> _predefinedItems = [];
  String? _selectedCategory;
  bool _isCustomItem = true;
  bool _isLoading = true;

  String? _imagePath; // For mobile
  String? _imageDataUrl; // For web

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
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    await _category_repository.initDefaultCategoriesIfEmpty();
    final categories = await _category_repository.getAllCategories();

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
    });
  }

  void _onPredefinedItemSelected(String itemName) {
    setState(() {
      _itemNameController.text = itemName;
      _isCustomItem = false;
    });
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imageHelper.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _imageDataUrl =
                'https://example.com/placeholder.jpg'; // Placeholder for web
          } else {
            _imagePath = image.path; // Temporary path for mobile
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Parse cost
      double? cost;
      if (_costController.text.isNotEmpty) {
        cost = double.tryParse(_costController.text);
      }

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
      );

      // Save image to permanent location if needed
      if (_imagePath != null &&
          _imagePath != widget.existingItem?.imagePath &&
          !kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${item.id}.jpg';
        final savedImage = File('${appDir.path}/$fileName');
        await File(_imagePath!).copy(savedImage.path);

        // Update with permanent path
        final updatedItem = RentalItem(
          id: item.id,
          kitId: item.kitId,
          name: item.name,
          dateAdded: item.dateAdded,
          imagePath: savedImage.path,
          imageDataUrl: item.imageDataUrl,
          category: item.category,
          notes: item.notes,
          cost: item.cost,
        );

        await _item_repository.saveRentalItem(updatedItem);
      } else {
        await _item_repository.saveRentalItem(item);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null
            ? AppStrings.addItem
            : 'Edit ${widget.existingItem!.name}'),
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
                    const Text(
                      'Item Photo (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Display existing image if any
                    if (_imagePath != null ||
                        _imageDataUrl != null ||
                        widget.existingItem?.imagePath != null ||
                        widget.existingItem?.imageDataUrl != null)
                      Container(
                        width: double.infinity,
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _imageHelper.buildItemImage(
                          RentalItem(
                            id: widget.existingItem?.id ?? 'temp',
                            kitId: widget.kitId,
                            name: _itemNameController.text,
                            dateAdded: DateTime.now(),
                            imagePath:
                                _imagePath ?? widget.existingItem?.imagePath,
                            imageDataUrl: _imageDataUrl ??
                                widget.existingItem?.imageDataUrl,
                          ),
                        ),
                      ),

                    // Take photo button
                    ElevatedButton.icon(
                      onPressed: _takePicture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text(AppStrings.takePhoto),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          widget.existingItem == null
                              ? AppStrings.add
                              : AppStrings.save,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
