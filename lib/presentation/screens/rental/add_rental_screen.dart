// lib/presentation/screens/rental/add_rental_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../../domain/entities/rental.dart';
import '../../../data/rental_repository.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/common_widgets.dart';
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
  final _imagePicker = ImagePickerHelper();

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
      final image = await _imagePicker.takePicture();

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
      // Create rental object with existing ID if editing
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

      // Handle image saving if needed
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

      // Return true to indicate successful save
      Navigator.of(context).pop(true);
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
              AppFormField(
                controller: _nameController,
                label: 'Rental Name',
                hint: 'Enter rental client or project name',
                required: true,
              ),

              const SizedBox(height: 16),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: DatePickerField(
                      label: 'Start Date',
                      date: _startDate,
                      onTap: _selectStartDate,
                    ),
                  ),
                  Expanded(
                    child: DatePickerField(
                      label: 'End Date',
                      date: _endDate,
                      onTap: _selectEndDate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location
              LocationPickerField(
                controller: _addressController,
                latitude: _latitude,
                longitude: _longitude,
                onPickLocation: _pickLocation,
                onGeocodeAddress: _geocodeAddress,
              ),

              const SizedBox(height: 16),

              // Photo Section
              ImagePickerField(
                imagePath: _imagePath,
                imageDataUrl: _imageDataUrl,
                onPickImage: _takePicture,
                label: 'Rental Photo (Optional)',
              ),

              const SizedBox(height: 16),

              // Notes
              AppFormField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Additional information about the rental',
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
}
