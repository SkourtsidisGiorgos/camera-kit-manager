import 'package:flutter/material.dart';
import '../models/rental_item.dart';
import '../models/equipment_category.dart';
import '../data/repository.dart';
import '../utils/constants.dart';

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
  final _repository = DataRepository();

  List<EquipmentCategory> _categories = [];
  List<String> _predefinedItems = [];
  String? _selectedCategory;
  bool _isCustomItem = true;
  bool _isLoading = true;

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
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    // Initialize default categories if this is first run
    await _repository.initDefaultCategoriesIfEmpty();

    // Get all categories
    final categories = await _repository.getAllCategories();

    setState(() {
      _categories = categories;
      _isLoading = false;

      // If there's an existing item with a category, select it
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

  Future<void> _saveItem() async {
    if (_formKey.currentState?.validate() ?? false) {
      final item = RentalItem(
        id: widget.existingItem?.id,
        kitId: widget.kitId,
        name: _itemNameController.text,
        dateAdded: widget.existingItem?.dateAdded ?? DateTime.now(),
        imagePath: widget.existingItem?.imagePath,
        imageDataUrl: widget.existingItem?.imageDataUrl,
        category: _selectedCategory,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await _repository.saveRentalItem(item);
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
