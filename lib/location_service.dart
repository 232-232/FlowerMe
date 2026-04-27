import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'pages/map_location_picker_page.dart';

class LocationResult {
  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
}

class LocationService {
  static const Duration _locationTimeout = Duration(seconds: 15);

  /// Step 3: Reverse geocodes lat/lng to a human-readable address (e.g.
  /// "12 MG Road, Bangalore, Karnataka, India"). Step 4: Opens fullscreen map
  /// picker (Uber-style: fixed center pin, map moves under it; search + bottom
  /// card with live address). Step 5: Returns [LocationResult] (latitude,
  /// longitude, formattedAddress) for the checkout page to fill the Address
  /// TextField. Returns null if permission denied or user cancels.
  static Future<LocationResult?> getCurrentLocation(
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final hasPermission = await _ensurePermission(context);
    if (!hasPermission) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Location permission denied. Please enable it to use this feature.'),
        ),
      );
      return null;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: _locationTimeout,
      );
    } on TimeoutException {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Unable to get location. GPS is taking too long.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              // Fire and forget – caller can trigger loading state again.
              LocationService.getCurrentLocation(context);
            },
          ),
        ),
      );
      return null;
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to get current location.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              LocationService.getCurrentLocation(context);
            },
          ),
        ),
      );
      return null;
    }

    final initialAddress = await _reverseGeocodeSafe(
      context,
      position.latitude,
      position.longitude,
    );

    final initialResult = LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      formattedAddress: initialAddress ??
          'Lat: ${position.latitude.toStringAsFixed(5)}, '
              'Lng: ${position.longitude.toStringAsFixed(5)}',
    );

    if (!context.mounted) return null;

    final picked = await Navigator.of(context).push<LocationResult>(
      MaterialPageRoute<LocationResult>(
        builder: (_) => MapLocationPickerPage(
          initialPosition: LatLng(
            initialResult.latitude,
            initialResult.longitude,
          ),
          initialAddress: initialResult.formattedAddress,
        ),
        fullscreenDialog: true,
      ),
    );

    return picked ?? initialResult;
  }

  static Future<bool> _ensurePermission(BuildContext context) async {
    // On web, Geolocator handles browser permission prompts.
    if (kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showServicesDisabledSnackBar(context);
        return false;
      }
      return true;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showServicesDisabledSnackBar(context);
      return false;
    }

    PermissionStatus status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedSnackBar(context);
      return false;
    }

    status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _showPermissionPermanentlyDeniedSnackBar(context);
      return false;
    }

    return false;
  }

  static void _showServicesDisabledSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location services are disabled. Please enable GPS.'),
      ),
    );
  }

  static void _showPermissionPermanentlyDeniedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location permission permanently denied. Please enable it from app settings.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  /// Reverse geocodes [latitude]/[longitude] to a human-readable address.
  /// On web: uses OpenStreetMap Nominatim (free, no API key required).
  /// On Android/iOS: uses the native OS geocoder via the `geocoding` package.
  static Future<String?> _reverseGeocodeSafe(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    if (kIsWeb) {
      return reverseGeocodeNominatim(latitude, longitude);
    }
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) return null;
      return formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  /// Calls Nominatim (OpenStreetMap) reverse geocoding — works on web without
  /// any API key. Exposed publicly so [LocationProvider] can reuse it.
  static Future<String?> reverseGeocodeNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude&lon=$longitude&format=json&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'DailyClub/1.0'},
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null) return null;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      // Build in the same style as native: road/street, suburb, city, state,
      // country → "MG Road, Bengaluru, Karnataka, India"
      final parts = <String>[
        for (final key in ['road', 'house_number'])
          if ((address[key] as String?)?.trim().isNotEmpty == true)
            (address[key] as String).trim(),
        for (final key in ['suburb', 'neighbourhood', 'quarter'])
          if ((address[key] as String?)?.trim().isNotEmpty == true) ...{
            (address[key] as String).trim(): null,
          }.keys,
        for (final key in ['city', 'town', 'village', 'county'])
          if ((address[key] as String?)?.trim().isNotEmpty == true) ...{
            (address[key] as String).trim(): null,
          }.keys,
        if ((address['state'] as String?)?.trim().isNotEmpty == true)
          (address['state'] as String).trim(),
        if ((address['country'] as String?)?.trim().isNotEmpty == true)
          (address['country'] as String).trim(),
      ];
      if (parts.isEmpty) {
        return data['display_name'] as String?;
      }
      // Deduplicate while preserving order
      final seen = <String>{};
      final unique = parts.where(seen.add).toList();
      return unique.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Exposed publicly so [LocationProvider] can reuse it on Android/iOS.
  static String formatPlacemark(geocoding.Placemark place) {
    final parts = <String>[
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
      if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
    ];
    return parts.join(', ');
  }
}

