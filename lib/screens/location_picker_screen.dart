// Create a new file: lib/screens/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String? _selectedAddress;
  bool _isLoading = true;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
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
    _mapController = controller;
    if (_selectedPosition != null) {
      controller
          .animateCamera(CameraUpdate.newLatLngZoom(_selectedPosition!, 14));
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _updateMarker(position);
      _getAddressFromLatLng(position);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
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
          : Stack(
              children: [
                GoogleMap(
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
            ),
    );
  }
}
