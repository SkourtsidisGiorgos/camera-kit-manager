// Create a new file: lib/screens/rental_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rental.dart';
import '../models/kit.dart';
import '../data/rental_repository.dart';
import '../data/repository.dart';
import '../utils/constants.dart';
import 'add_rental_screen.dart';
import 'item_list_screen.dart';

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
  final _kitRepository = DataRepository();
  List<Kit> _kits = [];
  List<Kit> _assignedKits = [];
  bool _isLoading = true;
  double _totalCost = 0.0;

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

    // Calculate total cost
    double total = 0.0;
    for (var kit in assignedKits) {
      final items = await _kitRepository.getRentalItemsByKitId(kit.id);
      for (var item in items) {
        if (item.cost != null) {
          total += item.cost!;
        }
      }
    }

    setState(() {
      _kits = allKits;
      _assignedKits = assignedKits;
      _totalCost = total;
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
              return ListTile(
                title: Text(kit.name),
                subtitle: Text(
                  'Created: ${DateFormat('MMM d, yyyy').format(kit.dateCreated)}',
                ),
                leading: CircleAvatar(
                  backgroundColor: kit.isOpen
                      ? AppColors.openStatus
                      : AppColors.closedStatus,
                  child: Icon(
                    kit.isOpen ? Icons.lock_open : Icons.lock,
                    color: Colors.white,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(kit),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Kit from Rental'),
        content: Text(
            'Are you sure you want to remove "${kit.name}" from this rental?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await _rentalRepository.removeKitFromRental(widget.rental.id, kit.id);
      _loadData();
    }
  }

  void _launchMaps() async {
    if (widget.rental.latitude == null || widget.rental.longitude == null) {
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.rental.latitude},${widget.rental.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  void _editRental() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                AddRentalScreen(existingRental: widget.rental),
          ),
        )
        .then((_) => _loadData());
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rental info card
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.rental.imagePath != null ||
                              widget.rental.imageDataUrl != null)
                            Container(
                              width: double.infinity,
                              height: 200,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: _buildRentalImage(),
                            ),
                          Text(
                            widget.rental.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Start: ${DateFormat('MMM d, yyyy').format(widget.rental.startDate)}',
                              ),
                            ],
                          ),
                          if (widget.rental.endDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.event_available, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'End: ${DateFormat('MMM d, yyyy').format(widget.rental.endDate!)}',
                                ),
                              ],
                            ),
                          ],
                          if (widget.rental.address != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: widget.rental.latitude != null
                                  ? _launchMaps
                                  : null,
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.rental.address!,
                                      style: TextStyle(
                                        color: widget.rental.latitude != null
                                            ? Colors.blue
                                            : null,
                                        decoration:
                                            widget.rental.latitude != null
                                                ? TextDecoration.underline
                                                : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.rental.notes != null &&
                              widget.rental.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Notes:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(widget.rental.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Total cost
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.openStatusLight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Equipment Cost:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '\$${_totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Assigned kits section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Equipment Kits',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ElevatedButton.icon(
                          onPressed: _assignKit,
                          icon: const Icon(Icons.add),
                          label: const Text('Assign Kit'),
                        ),
                      ],
                    ),
                  ),

                  if (_assignedKits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No equipment kits assigned yet'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _assignedKits.length,
                      itemBuilder: (context, index) {
                        final kit = _assignedKits[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(kit.name),
                            subtitle: Text(
                              'Status: ${kit.isOpen ? "Open" : "Closed"}',
                            ),
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
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ItemListScreen(kit: kit),
                                      ),
                                    );
                                  },
                                  tooltip: 'View Items',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () => _removeKit(kit),
                                  tooltip: 'Remove from Rental',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRentalImage() {
    if (kIsWeb && widget.rental.imageDataUrl != null) {
      return Image.network(
        widget.rental.imageDataUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100),
      );
    } else if (!kIsWeb && widget.rental.imagePath != null) {
      return Image.file(
        File(widget.rental.imagePath!),
        fit: BoxFit.cover,
      );
    } else {
      return const Center(child: Icon(Icons.image_not_supported, size: 100));
    }
  }
}
