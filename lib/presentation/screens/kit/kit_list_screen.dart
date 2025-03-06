import 'package:camera_kit_manager/presentation/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/kit.dart';
import '../../../domain/entities/rental.dart';
import '../../../data/kit_repository.dart';
import '../../../data/rental_repository.dart';
import '../../../data/item_repository.dart';
import '../../../core/utils/constants.dart';
import '../../widgets/ui_components.dart';
import 'item_list_screen.dart';

class KitListScreen extends StatefulWidget {
  const KitListScreen({super.key});

  @override
  State<KitListScreen> createState() => _KitListScreenState();
}

class _KitListScreenState extends State<KitListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kitNameController = TextEditingController();
  final _kitRepository = KitRepository();
  final _rentalRepository = RentalRepository();
  final _itemRepository = ItemRepository();
  List<Kit> _kits = [];
  List<Rental> _rentals = [];
  Rental? _selectedRental;
  bool _isLoading = true;
  Map<String, double> _kitCosts = {};

  @override
  void initState() {
    super.initState();
    _refreshKits();
  }

  @override
  void dispose() {
    _kitNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshKits() async {
    setState(() => _isLoading = true);
    final kits = await _kitRepository.getAllKits();

    // Calculate cost for each kit
    Map<String, double> kitCosts = {};
    for (var kit in kits) {
      final items = await _itemRepository.getRentalItemsByKitId(kit.id);
      double totalCost = 0.0;
      for (var item in items) {
        if (item.cost != null) {
          totalCost += item.cost!;
        }
      }
      kitCosts[kit.id] = totalCost;
    }

    setState(() {
      _kits = kits..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
      _kitCosts = kitCosts;
      _isLoading = false;
    });
  }

  Future<void> _loadRentals() async {
    final rentals = await _rentalRepository.getAllRentals();
    setState(() {
      _rentals = rentals..sort((a, b) => b.startDate.compareTo(a.startDate));
    });
  }

  Future<void> _addKit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newKit = Kit(
        name: _kitNameController.text,
        dateCreated: DateTime.now(),
        isOpen: true,
      );

      await _kitRepository.saveKit(newKit);

      // Associate kit with the selected rental if any
      if (_selectedRental != null) {
        await _rentalRepository.addKitToRental(_selectedRental!.id, newKit.id);
      }

      _kitNameController.clear();
      Navigator.of(context).pop();
      _refreshKits();
    }
  }

  Future<void> _toggleKitStatus(Kit kit) async {
    final updatedKit = Kit(
      id: kit.id,
      name: kit.name,
      dateCreated: kit.dateCreated,
      isOpen: !kit.isOpen,
    );

    await _kitRepository.updateKit(updatedKit);
    _refreshKits();
  }

  void _showAddKitDialog() async {
    // Reset selection state
    _selectedRental = null;
    _kitNameController.clear();

    // Load available rentals
    await _loadRentals();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(AppStrings.newKit),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppFormField(
                      controller: _kitNameController,
                      label: AppStrings.kitName,
                      hint: AppStrings.kitNameHint,
                      required: true,
                    ),
                    const SizedBox(height: 16),

                    // Rental dropdown (optional)
                    if (_rentals.isNotEmpty) ...[
                      const Text(
                        'Assign to Rental (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<Rental>(
                        isExpanded: true,
                        hint: const Text('Select a rental (optional)'),
                        value: _selectedRental,
                        items: [
                          // Add a "None" option
                          const DropdownMenuItem<Rental>(
                            value: null,
                            child: Text('None'),
                          ),
                          ..._rentals.map((rental) {
                            return DropdownMenuItem<Rental>(
                              value: rental,
                              child: Text(rental.name),
                            );
                          }),
                        ],
                        onChanged: (Rental? rental) {
                          setState(() {
                            _selectedRental = rental;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(AppStrings.cancel),
              ),
              ElevatedButton(
                onPressed: _addKit,
                child: const Text(AppStrings.create),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditKitDialog(Kit kit) {
    _kitNameController.text = kit.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Kit'),
        content: Form(
          key: _formKey,
          child: AppFormField(
            controller: _kitNameController,
            label: AppStrings.kitName,
            hint: AppStrings.kitNameHint,
            required: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => _updateKit(kit),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _updateKit(Kit kit) async {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedKit = Kit(
        id: kit.id,
        name: _kitNameController.text,
        dateCreated: kit.dateCreated,
        isOpen: kit.isOpen,
      );

      await _kitRepository.updateKit(updatedKit);
      _kitNameController.clear();
      Navigator.of(context).pop();
      _refreshKits();
    }
  }

  Future<void> _deleteKit(Kit kit) async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: AppStrings.deleteKit,
      message:
          'Are you sure you want to delete "${kit.name}"? ${AppStrings.deleteKitConfirm}',
      confirmText: AppStrings.delete,
      isDangerous: true,
    );

    if (confirm) {
      await _kitRepository.deleteKit(kit.id);
      _refreshKits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const LoadingView()
          : _kits.isEmpty
              ? const EmptyStateView(
                  message: AppStrings.noKits,
                  icon: Icons.camera,
                )
              : ListView.builder(
                  itemCount: _kits.length,
                  itemBuilder: (context, index) {
                    final kit = _kits[index];
                    return _buildKitTile(kit);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddKitDialog,
        tooltip: 'Add New Kit',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildKitTile(Kit kit) {
    final kitCost = _kitCosts[kit.id] ?? 0.0;

    return AppCard(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => ItemListScreen(kit: kit),
              ),
            )
            .then((_) => _refreshKits());
      },
      child: Column(
        children: [
          ListTile(
            title: Text(kit.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created: ${DateFormatter.format(kit.dateCreated)}'),
                Text(
                  'Total Cost: \$${kitCost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            leading: StatusBadge(isOpen: kit.isOpen),
            trailing: ActionButtons(
              actions: [
                ActionButton(
                  icon: Icons.edit,
                  onPressed: () => _showEditKitDialog(kit),
                  tooltip: 'Edit Kit',
                ),
                ActionButton(
                  icon: kit.isOpen ? Icons.lock : Icons.lock_open,
                  onPressed: () => _toggleKitStatus(kit),
                  color: kit.isOpen
                      ? AppColors.closedStatus
                      : AppColors.openStatus,
                  tooltip:
                      kit.isOpen ? AppStrings.closeKit : AppStrings.reopenKit,
                ),
                ActionButton(
                  icon: Icons.delete,
                  onPressed: () => _deleteKit(kit),
                  color: Colors.grey,
                  tooltip: AppStrings.delete,
                ),
              ],
            ),
          ),
          if (kitCost > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total Cost: \$${kitCost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
