import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/rental.dart';
import '../../data/rental_repository.dart';
import '../../utils/constants.dart';
import 'add_rental_screen.dart';
import 'rental_details_screen.dart';

class RentalListScreen extends StatefulWidget {
  const RentalListScreen({super.key});

  @override
  State<RentalListScreen> createState() => _RentalListScreenState();
}

class _RentalListScreenState extends State<RentalListScreen> {
  final _repository = RentalRepository();
  List<Rental> _rentals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshRentals();
  }

  Future<void> _refreshRentals() async {
    setState(() => _isLoading = true);
    final rentals = await _repository.getAllRentals();
    setState(() {
      _rentals = rentals..sort((a, b) => b.startDate.compareTo(a.startDate));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rentals.isEmpty
              ? const Center(
                  child: Text(
                    'No rentals yet.\nTap "+" to add a new rental.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _rentals.length,
                  itemBuilder: (context, index) {
                    final rental = _rentals[index];
                    final startDate =
                        DateFormat('MMM d, yyyy').format(rental.startDate);
                    final endDate = rental.endDate != null
                        ? DateFormat('MMM d, yyyy').format(rental.endDate!)
                        : 'Ongoing';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(rental.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From: $startDate'),
                            Text('To: $endDate'),
                            if (rental.address != null)
                              Text('Location: ${rental.address}'),
                          ],
                        ),
                        leading: rental.imageDataUrl != null ||
                                rental.imagePath != null
                            ? CircleAvatar(
                                backgroundImage: rental.imageDataUrl != null
                                    ? NetworkImage(rental.imageDataUrl!)
                                    : FileImage(File(rental.imagePath!))
                                        as ImageProvider,
                              )
                            : const CircleAvatar(
                                child: Icon(Icons.receipt),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rental.latitude != null &&
                                rental.longitude != null)
                              IconButton(
                                icon: const Icon(Icons.map,
                                    color: AppColors.primary),
                                onPressed: () => _launchMaps(rental),
                                tooltip: 'Open in Maps',
                              ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteRental(rental),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RentalDetailsScreen(rental: rental),
                                ),
                              )
                              .then((_) => _refreshRentals());
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => const AddRentalScreen(),
                ),
              )
              .then((_) => _refreshRentals());
        },
        tooltip: 'Add New Rental',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteRental(Rental rental) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rental?'),
        content: Text('Are you sure you want to delete "${rental.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await _repository.deleteRental(rental.id);
      _refreshRentals();
    }
  }

  void _launchMaps(Rental rental) async {
    if (rental.latitude == null || rental.longitude == null) return;

    final url =
        'https://www.google.com/maps/search/?api=1&query=${rental.latitude},${rental.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }
}
