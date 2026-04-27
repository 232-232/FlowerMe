import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location_service.dart';
import 'places_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider({required LocationResult initialResult})
      : _currentLatLng = LatLng(
          initialResult.latitude,
          initialResult.longitude,
        ),
        _selectedAddress = initialResult.formattedAddress;

  static const Duration _geocodeDebounceDuration =
      Duration(milliseconds: 500);
  static const Duration _searchDebounceDuration =
      Duration(milliseconds: 400);

  // ── Map state ──────────────────────────────────────────────────────────────
  LatLng _currentLatLng;
  String _selectedAddress;
  bool _isFetchingAddress = false;
  bool _isMapMoving = false;
  String? _errorMessage;
  Timer? _geocodeDebounce;
  LocationResult? _cachedResult;

  // ── Search / autocomplete state ────────────────────────────────────────────
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _searchDebounce;
  String? _sessionToken;

  // ── GPS fetch state ────────────────────────────────────────────────────────
  bool _isFetchingLocation = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  LatLng get currentLatLng => _currentLatLng;
  String get selectedAddress => _selectedAddress;
  bool get isFetchingAddress => _isFetchingAddress;
  bool get isMapMoving => _isMapMoving;
  String? get errorMessage => _errorMessage;
  List<PlaceSuggestion> get suggestions =>
      List<PlaceSuggestion>.unmodifiable(_suggestions);
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  bool get isFetchingLocation => _isFetchingLocation;

  LocationResult get currentResult => LocationResult(
        latitude: _currentLatLng.latitude,
        longitude: _currentLatLng.longitude,
        formattedAddress: _selectedAddress,
      );

  // ── Map camera events ──────────────────────────────────────────────────────

  void onCameraMoveStarted() {
    if (!_isMapMoving) {
      _isMapMoving = true;
      notifyListeners();
    }
  }

  void onCameraMove(LatLng target) {
    _currentLatLng = target;
    if (!_isMapMoving) {
      _isMapMoving = true;
      notifyListeners();
    }
  }

  void onCameraIdle(BuildContext context) {
    _isMapMoving = false;
    notifyListeners();
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(
      _geocodeDebounceDuration,
      () => _reverseGeocode(context, _currentLatLng),
    );
  }

  // ── Places autocomplete ────────────────────────────────────────────────────

  void onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _suggestions = [];
      _isLoadingSuggestions = false;
      _sessionToken = null;
      notifyListeners();
      return;
    }
    // Reuse same session token for all queries in one search session.
    _sessionToken ??=
        DateTime.now().millisecondsSinceEpoch.toString();
    _isLoadingSuggestions = true;
    notifyListeners();

    _searchDebounce = Timer(_searchDebounceDuration, () async {
      final results = await PlacesService.autocomplete(
        query,
        sessionToken: _sessionToken,
      );
      _suggestions = results;
      _isLoadingSuggestions = false;
      notifyListeners();
    });
  }

  Future<void> selectSuggestion(
    PlaceSuggestion suggestion,
    GoogleMapController controller,
    BuildContext context,
  ) async {
    // Closing the session token here ends the billing session.
    final token = _sessionToken;
    _sessionToken = null;
    _suggestions = [];
    _isLoadingSuggestions = false;
    notifyListeners();

    final latLng = await PlacesService.getDetails(
      suggestion.placeId,
      sessionToken: token,
    );
    if (latLng == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load location details. Please try again.',
            ),
          ),
        );
      }
      return;
    }
    _currentLatLng = latLng;
    notifyListeners();
    await controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
  }

  void clearSuggestions() {
    _searchDebounce?.cancel();
    _suggestions = [];
    _isLoadingSuggestions = false;
    _sessionToken = null;
    notifyListeners();
  }

  // ── GPS current location ───────────────────────────────────────────────────

  Future<void> fetchCurrentLocation(
    BuildContext context,
    GoogleMapController controller,
  ) async {
    if (_isFetchingLocation) return;
    _isFetchingLocation = true;
    notifyListeners();

    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location services are disabled. Please enable GPS.',
                ),
              ),
            );
          }
          return;
        }

        PermissionStatus status =
            await Permission.locationWhenInUse.status;
        if (status.isPermanentlyDenied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Location permission permanently denied. '
                  'Please enable it from app settings.',
                ),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                ),
              ),
            );
          }
          return;
        }
        if (!status.isGranted) {
          status = await Permission.locationWhenInUse.request();
          if (!status.isGranted) return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLatLng = latLng;
      notifyListeners();
      await controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('GPS is taking too long. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get current location.'),
          ),
        );
      }
    } finally {
      _isFetchingLocation = false;
      notifyListeners();
    }
  }

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  Future<void> _reverseGeocode(BuildContext context, LatLng target) async {
    final last = _cachedResult;
    if (last != null &&
        _distanceInMeters(
              last.latitude,
              last.longitude,
              target.latitude,
              target.longitude,
            ) <
            5) {
      _selectedAddress = last.formattedAddress;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isFetchingAddress = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? address;
      if (kIsWeb) {
        address = await LocationService.reverseGeocodeNominatim(
          target.latitude,
          target.longitude,
        );
      } else {
        final placemarks = await geocoding.placemarkFromCoordinates(
          target.latitude,
          target.longitude,
        );
        if (placemarks.isNotEmpty) {
          address = LocationService.formatPlacemark(placemarks.first);
        }
      }

      if (address == null || address.trim().isEmpty) {
        _errorMessage = 'No address found for this location.';
        _isFetchingAddress = false;
        notifyListeners();
        return;
      }
      _selectedAddress = address;
      _cachedResult = LocationResult(
        latitude: target.latitude,
        longitude: target.longitude,
        formattedAddress: _selectedAddress,
      );
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Failed to update address. Check your network.';
    } finally {
      _isFetchingAddress = false;
      notifyListeners();
    }
  }

  double _distanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
