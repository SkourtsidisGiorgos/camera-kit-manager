// lib/presentation/screens/rental/rental_details_screen.dart
import 'package:camera_kit_manager/presentation/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/rental.dart';
import '../../../domain/entities/kit.dart';
import '../../../data/rental_repository.dart';
import '../../../data/kit_repository.dart';
import '../../../data/item_repository.dart';
import '../../widgets/common_widgets.dart';
import '../kit/item_list_screen.dart';
import 'add_rental_screen.dart';

class RentalDetailsScreen extends StatefulWidget {
  final Rental rental;

  const RentalDetailsScreen({
    super.key,
    required this.rental,
  });

  @override
  State<RentalDetailsScreen> createState() => _RentalDetailsScreenState();
}

class _RentalDetailsScreenState extends State<RentalDetailsScreen> {
  final _rentalRepository = RentalRepository();
  final _kitRepository = KitRepository();
  final _itemRepository = ItemRepository();
  List<Kit> _kits = [];
  List<Kit> _assignedKits = [];
  bool _isLoading = true;
  double _totalCost = 0.0;

  // Store individual kit costs
  Map<String, double> _kitCosts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load all kits
    final allKits = await _kitRepository.getAllKits();

    // Load assigned kits
    final assignedKits =
        await _rentalRepository.getKitsByRental(widget.rental.id);

    // Calculate total cost and individual kit costs
    double total = 0.0;
    Map<String, double> kitCosts = {};

    for (var kit in assignedKits) {
      final items = await _itemRepository.getRentalItemsByKitId(kit.id);
      double kitTotal = 0.0;

      for (var item in items) {
        if (item.cost != null) {
          kitTotal += item.cost!;
        }
      }

      kitCosts[kit.id] = kitTotal;
      total += kitTotal;
    }

    setState(() {
      _kits = allKits;
      _assignedKits = assignedKits;
      _totalCost = total;
      _kitCosts = kitCosts;
      _isLoading = false;
    });
  }

  Future<void> _assignKit() async {
    // Filter out already assigned kits
    final availableKits = _kits
        .where((kit) => !_assignedKits.any((assigned) => assigned.id == kit.id))
        .toList();

    if (availableKits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All kits are already assigned to this rental')),
      );
      return;
    }

    final selectedKit = await showDialog<Kit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Equipment Kit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableKits.length,
            itemBuilder: (context, index) {
              final kit = availableKits[index];
              return KitListTile(
                kit: kit,
                onTap: () => Navigator.of(context).pop(kit),
                actions: const [], // No actions needed here
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedKit != null) {
      await _rentalRepository.addKitToRental(widget.rental.id, selectedKit.id);
      _loadData();
    }
  }

  Future<void> _removeKit(Kit kit) async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Kit from Rental',
      message:
          'Are you sure you want to remove "${kit.name}" from this rental?',
      confirmText: 'Remove',
      isDangerous: true,
    );

    if (confirm) {
      await _rentalRepository.removeKitFromRental(widget.rental.id, kit.id);
      _loadData();
    }
  }

  void _launchMaps() async {
    if (widget.rental.latitude != null && widget.rental.longitude != null) {
      openMapsLink(context, widget.rental.latitude!, widget.rental.longitude!);
    }
  }

  void _editRental() async {
    // Navigate to edit screen and wait for result
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddRentalScreen(existingRental: widget.rental),
      ),
    );

    if (result == true) {
      // Get the updated rental data from the repository
      final updatedRental =
          await _rentalRepository.getRentalById(widget.rental.id);

      if (updatedRental != null && mounted) {
        // Replace the current screen with a fresh instance
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RentalDetailsScreen(rental: updatedRental),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rental.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editRental,
            tooltip: 'Edit Rental',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rental info card
                  RentalInfoTile(
                    rental: widget.rental,
                    onMapTap: _launchMaps,
                  ),

                  // Total cost summary for all kits
                  CostSummaryTile(
                    totalCost: _totalCost,
                    title: 'Total Equipment Cost:',
                  ),

                  // Assigned kits section
                  const SectionHeader(
                    title: 'Assigned Equipment Kits',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      onPressed: _assignKit,
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Kit'),
                    ),
                  ),

                  if (_assignedKits.isEmpty)
                    const EmptyStateView(
                      message: 'No equipment kits assigned yet',
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _assignedKits.length,
                      itemBuilder: (context, index) {
                        final kit = _assignedKits[index];
                        return _buildKitCard(kit);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildKitCard(Kit kit) {
    final kitCost = _kitCosts[kit.id] ?? 0.0;

    return AppCard(
      child: Column(
        children: [
          ListTile(
            title: Text(kit.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${kit.isOpen ? "Open" : "Closed"}'),
                Text(
                  'Cost: \$${kitCost.toStringAsFixed(2)}',
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
                  icon: Icons.visibility,
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => ItemListScreen(kit: kit),
                          ),
                        )
                        .then((_) => _loadData());
                  },
                  tooltip: 'View Items',
                ),
                ActionButton(
                  icon: Icons.remove_circle_outline,
                  onPressed: () => _removeKit(kit),
                  color: Colors.red,
                  tooltip: 'Remove from Rental',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
