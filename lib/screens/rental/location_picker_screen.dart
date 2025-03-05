// Modified LocationPickerScreen with error handling
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedPosition;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _mapError = false; // Track if map fails to load
  String _errorMessage = 'Unable to load map';
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();

    // Setup error handling for async errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // If it's a map-related error, handle it
      String error = details.exception.toString();
      if (error.contains('map') ||
          error.contains('API key') ||
          error.contains('PlatformException')) {
        _onMapError(details.exception);
      } else {
        // Otherwise, let Flutter handle it normally
        FlutterError.presentError(details);
      }
    };
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    // If initial coordinates are provided, use them
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _updateMarker(_selectedPosition!);
      _getAddressFromLatLng(_selectedPosition!);
    } else {
      // Otherwise try to get current location
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _updateMarker(_selectedPosition!);
          _getAddressFromLatLng(_selectedPosition!);
        }
      } catch (e) {
        // Use default position if permission denied or error
        _selectedPosition =
            const LatLng(37.42796133580664, -122.085749655962); // Google HQ
        _updateMarker(_selectedPosition!);
      }
    }

    setState(() => _isLoading = false);
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selectedLocation'),
          position: position,
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
      };
    });
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Address not available';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (_selectedPosition != null) {
      controller
          .animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition!, 14))
          .catchError((error) {
        // Handle any animation errors
        _onMapError(error);
      });
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _updateMarker(position);
      _getAddressFromLatLng(position);
    });
  }

  void _onMapError(Object e) {
    setState(() {
      _mapError = true;
      // Check error type to provide more specific message
      if (e.toString().contains("API key")) {
        _errorMessage = 'Google Maps API key not configured.';
      } else {
        _errorMessage = 'Unable to load map: ${e.toString()}';
      }
      _isLoading = false;
    });
  }

  void _confirmLocation() {
    if (_selectedPosition != null) {
      Navigator.of(context).pop({
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        'address': _selectedAddress,
      });
    }
  }

  void _manuallyEnterLocation() async {
    // Show a dialog for manually entering coordinates
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildManualLocationDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedPosition = LatLng(result['latitude'], result['longitude']);
        _selectedAddress = result['address'] ?? 'Custom location';
        _updateMarker(_selectedPosition!);
      });
    }
  }

  Widget _buildManualLocationDialog() {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final addressController = TextEditingController();

    return AlertDialog(
      title: const Text('Enter Location Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 37.4219983',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. -122.084',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final lat = double.tryParse(latController.text);
            final lng = double.tryParse(lngController.text);

            if (lat != null && lng != null) {
              Navigator.of(context).pop({
                'latitude': lat,
                'longitude': lng,
                'address': addressController.text.isEmpty
                    ? null
                    : addressController.text,
              });
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          // Add manual entry option in app bar
          IconButton(
            icon: const Icon(Icons.edit_location_alt),
            onPressed: _manuallyEnterLocation,
            tooltip: 'Enter Coordinates',
          ),
          if (_selectedPosition != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _confirmLocation,
              tooltip: 'Confirm Location',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mapError
              ? _buildMapErrorView()
              : buildMapViewWithErrorHandling(),
    );
  }

  // New method to handle potential exceptions from GoogleMap widget
  Widget buildMapViewWithErrorHandling() {
    return FutureBuilder<bool>(
      // Use a short-lived future to allow for error handling
      future: Future.delayed(const Duration(milliseconds: 300), () => true)
          .catchError((error) {
        _onMapError(error);
        return false;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Handle errors from the future
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onMapError(snapshot.error!);
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data != true) {
          return const Center(child: CircularProgressIndicator());
        }

        // If we get here, try to build the map view
        return _buildMapView();
      },
    );
  }

  Widget _buildMapErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _manuallyEnterLocation,
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Manually Enter Location'),
            ),
            if (_selectedPosition != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Selected Location:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedAddress != null) Text(_selectedAddress!),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_selectedPosition!.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: const Text('Confirm Location'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // Wrap GoogleMap in a try-catch at runtime using Builder
        Builder(
          builder: (context) {
            try {
              return GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _selectedPosition ??
                      const LatLng(37.42796133580664, -122.085749655962),
                  zoom: 14,
                ),
                markers: _markers,
                onTap: _onMapTap,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              );
            } catch (e) {
              // This will catch runtime exceptions, but not async failures
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onMapError(e);
              });
              return Container(); // Return empty container until error state updates
            }
          },
        ),
        if (_selectedAddress != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selected Location:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_selectedAddress!),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_selectedPosition!.latitude.toStringAsFixed(6)}, Lng: ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      child: const Text('Confirm Location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
