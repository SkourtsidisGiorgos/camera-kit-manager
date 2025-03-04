# Project Structure

```
lib/
├── main.dart                    # Main app entry point
├── models/
│   ├── kit.dart                 # Kit model (renamed from "renting")
│   ├── rental_item.dart         # Rental item model 
│   └── equipment_category.dart  # Equipment categories and predefined items
├── data/
│   └── repository.dart          # Data access layer
├── screens/
│   ├── kit_list_screen.dart     # List of kits/rentals
│   ├── item_list_screen.dart    # Items in a specific kit
│   └── add_item_screen.dart     # Screen to add items with categories
└── utils/
    ├── constants.dart           # App constants
    └── image_helper.dart        # Image handling utilities
```