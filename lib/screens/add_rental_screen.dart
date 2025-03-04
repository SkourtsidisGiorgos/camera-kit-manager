// Create a new file: lib/screens/add_rental_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import '../models/rental.dart';
import '../data/rental_repository.dart';
import 'location_picker_screen.dart';

class AddRentalScreen extends StatefulWidget {
  final Rental? existingRental;

  const AddRentalScreen({
    super.key,
    this.existingRental,
  });

  @override
  State<AddRentalScreen> createState() => _AddRentalScreenState();
}

class _AddRentalScreenState extends State<AddRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _repository = RentalRepository();
  final _imagePicker = ImagePicker();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;
  String? _imagePath;
  String? _imageDataUrl;

  @override
  void initState() {
    super.initState();

    // If editing an existing rental
    if (widget.existingRental != null) {
      _nameController.text = widget.existingRental!.name;
      _startDate = widget.existingRental!.startDate;
      _endDate = widget.existingRental!.endDate;
      _addressController.text = widget.existingRental!.address ?? '';
      _latitude = widget.existingRental!.latitude;
      _longitude = widget.existingRental!.longitude;
      _imagePath = widget.existingRental!.imagePath;
      _imageDataUrl = widget.existingRental!.imageDataUrl;
      if (widget.existingRental!.notes != null) {
        _notesController.text = widget.existingRental!.notes!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // If end date is now before start date, reset it
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _addressController.text = result['address'] ?? '';
      });
    }
  }

  Future<void> _geocodeAddress() async {
    if (_addressController.text.isEmpty) return;

    try {
      final locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find location: ${e.toString()}')),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
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

  Future<void> _saveRental() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Create rental object
      final rental = Rental(
        id: widget.existingRental?.id,
        name: _nameController.text,
        startDate: _startDate,
        endDate: _endDate,
        address:
            _addressController.text.isEmpty ? null : _addressController.text,
        latitude: _latitude,
        longitude: _longitude,
        imagePath: _imagePath ?? widget.existingRental?.imagePath,
        imageDataUrl: _imageDataUrl ?? widget.existingRental?.imageDataUrl,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        kitIds: widget.existingRental?.kitIds,
      );

      // Save image to permanent location if needed
      if (_imagePath != null &&
          _imagePath != widget.existingRental?.imagePath &&
          !kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_rental_${rental.id}.jpg';
        final savedImage = File('${appDir.path}/$fileName');
        await File(_imagePath!).copy(savedImage.path);

        // Update with permanent path
        final updatedRental = Rental(
          id: rental.id,
          name: rental.name,
          startDate: rental.startDate,
          endDate: rental.endDate,
          address: rental.address,
          latitude: rental.latitude,
          longitude: rental.longitude,
          imagePath: savedImage.path,
          imageDataUrl: rental.imageDataUrl,
          notes: rental.notes,
          kitIds: rental.kitIds,
        );

        await _repository.saveRental(updatedRental);
      } else {
        await _repository.saveRental(rental);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRental == null
            ? 'Add Rental'
            : 'Edit ${widget.existingRental!.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rental Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Rental Name',
                  hintText: 'Enter rental client or project name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Date'),
                      subtitle:
                          Text(DateFormat('MMM d, yyyy').format(_startDate)),
                      onTap: () => _selectStartDate(context),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Date'),
                      subtitle: _endDate != null
                          ? Text(DateFormat('MMM d, yyyy').format(_endDate!))
                          : const Text('Not set'),
                      onTap: () => _selectEndDate(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter location address',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _geocodeAddress,
                    tooltip: 'Find location',
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Map button
              ElevatedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map),
                label: const Text('Pick Location on Map'),
              ),

              // Display location coordinates if available
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Location: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              const SizedBox(height: 16),

              // Photo Section
              const Text(
                'Rental Photo (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Display existing image if any
              if (_imagePath != null ||
                  _imageDataUrl != null ||
                  widget.existingRental?.imagePath != null ||
                  widget.existingRental?.imageDataUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _buildRentalImage(),
                ),

              // Take photo button
              ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional information about the rental',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRental,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.existingRental == null
                        ? 'Add Rental'
                        : 'Save Changes',
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

  Widget _buildRentalImage() {
    if (kIsWeb) {
      // For web platform
      if (_imageDataUrl != null) {
        return Image.network(
          _imageDataUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 100),
        );
      } else if (widget.existingRental?.imageDataUrl != null) {
        return Image.network(
          widget.existingRental!.imageDataUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 100),
        );
      }
    } else {
      // For mobile platform
      if (_imagePath != null) {
        return Image.file(
          File(_imagePath!),
          fit: BoxFit.cover,
        );
      } else if (widget.existingRental?.imagePath != null) {
        return Image.file(
          File(widget.existingRental!.imagePath!),
          fit: BoxFit.cover,
        );
      }
    }

    return const Icon(Icons.image, size: 100);
  }
}
