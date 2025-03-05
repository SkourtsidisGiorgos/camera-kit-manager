import 'package:flutter/material.dart';

class AppColors {
  static const MaterialColor primary = Colors.blue;
  static const Color openStatus = Colors.green;
  static const Color closedStatus = Colors.red;
  static const Color openStatusLight = Color(0xFFE8F5E9); // Green 50
  static const Color closedStatusLight = Color(0xFFFFEBEE); // Red 50
}

class AppStrings {
  static const String appTitle = 'Camera Kit Manager';

  static const String cancel = 'Cancel';
  static const String create = 'Create';
  static const String add = 'Add';
  static const String delete = 'Delete';
  static const String share = 'Share';
  static const String save = 'Save';

  // Kit related
  static const String newKit = 'New Equipment Kit';
  static const String kitName = 'Kit Name';
  static const String kitNameHint =
      'e.g., Red Camera Setup, Location Sound Kit';
  static const String kitNameValidator = 'Please enter a kit name';
  static const String deleteKit = 'Delete Kit?';
  static const String deleteKitConfirm =
      'Are you sure you want to delete this kit? This will delete all items in this kit.';
  static const String statusOpen = 'OPEN';
  static const String statusClosed = 'CLOSED';
  static const String closeKit = 'Close Kit';
  static const String reopenKit = 'Reopen Kit';
  static const String noKits =
      'No equipment kits yet.\nTap "+" to create a new kit.';

  // Item related
  static const String addItem = 'Add Equipment Item';
  static const String itemName = 'Item Name';
  static const String itemNameHint = 'e.g., Camera Body, Lens 50mm, Tripod';
  static const String itemNameValidator = 'Please enter an item name';
  static const String deleteItem = 'Delete Item?';
  static const String deleteItemConfirm =
      'Are you sure you want to delete this item?';
  static const String noItems =
      'No equipment items in this kit yet.\nTap "+" to add items.';
  static const String cannotAddToClosed = 'Cannot add items to a closed kit';
  static const String cannotModifyClosed =
      'Cannot modify items in a closed kit';
  static const String takePhoto = 'Take Photo';
  static const String category = 'Category';
  static const String selectCategory = 'Select Category';
  static const String notes = 'Notes (Optional)';
  static const String notesHint = 'Serial number, condition, etc.';

  // Category related
  static const String addCategory = 'Add Category';
  static const String categoryName = 'Category Name';
  static const String categoryNameHint = 'e.g., Lenses, Audio, Support';
  static const String categoryNameValidator = 'Please enter a category name';
  static const String selectFromPredefined = 'Select from predefined items';
  static const String customItem = 'Custom Item';
}
