import 'package:camera_kit_manager/data/kit_repository.dart';
import 'package:camera_kit_manager/screens/kit/item_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/kit.dart';
import '../../models/rental.dart';
import '../../data/rental_repository.dart';
import '../../utils/constants.dart';

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
  List<Kit> _kits = [];
  List<Rental> _rentals = [];
  Rental? _selectedRental;
  bool _isLoading = true;

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
    setState(() {
      _kits = kits..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
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
                    TextFormField(
                      controller: _kitNameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.kitName,
                        hintText: AppStrings.kitNameHint,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.kitNameValidator;
                        }
                        return null;
                      },
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
          child: TextFormField(
            controller: _kitNameController,
            decoration: const InputDecoration(
              labelText: AppStrings.kitName,
              hintText: AppStrings.kitNameHint,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppStrings.kitNameValidator;
              }
              return null;
            },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kits.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.noKits,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  itemCount: _kits.length,
                  itemBuilder: (context, index) {
                    final kit = _kits[index];
                    final formattedDate =
                        DateFormat('MMM d, yyyy').format(kit.dateCreated);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(kit.name),
                        subtitle: Text('Created: $formattedDate'),
                        leading: CircleAvatar(
                          backgroundColor: kit.isOpen
                              ? AppColors.openStatus
                              : AppColors.closedStatus,
                          child: Icon(
                            kit.isOpen ? Icons.lock_open : Icons.lock,
                            color: Colors.white,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditKitDialog(kit),
                              tooltip: 'Edit Kit',
                            ),
                            IconButton(
                              icon: Icon(
                                kit.isOpen ? Icons.lock : Icons.lock_open,
                                color: kit.isOpen
                                    ? AppColors.closedStatus
                                    : AppColors.openStatus,
                              ),
                              onPressed: () => _toggleKitStatus(kit),
                              tooltip: kit.isOpen
                                  ? AppStrings.closeKit
                                  : AppStrings.reopenKit,
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(AppStrings.deleteKit),
                                    content: Text(
                                        'Are you sure you want to delete "${kit.name}"? ${AppStrings.deleteKitConfirm}'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text(AppStrings.cancel),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text(AppStrings.delete,
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm ?? false) {
                                  await _kitRepository.deleteKit(kit.id);
                                  _refreshKits();
                                }
                              },
                              tooltip: AppStrings.delete,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ItemListScreen(kit: kit),
                                ),
                              )
                              .then((_) => _refreshKits());
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddKitDialog,
        tooltip: 'Add New Kit',
        child: const Icon(Icons.add),
      ),
    );
  }
}
