import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Fee Service
// Fetches store GPS from root/storeAdrs/adrs, then computes:
//   • straight-line distance (Haversine, km)
//   • delivery fee:  ≤5 km → ₹0,  >5 km → (distance − 5) × ₹10
//   • estimated delivery time (5 min base + 2 min/km)
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryInfo {
  const DeliveryInfo({
    required this.distanceKm,
    required this.deliveryFee,
    required this.etaMinutes,
  });

  final double distanceKm;
  final double deliveryFee;
  final int etaMinutes;

  /// E.g. "2.3 km"
  String get distanceLabel => distanceKm < 1
      ? '${(distanceKm * 1000).toStringAsFixed(0)} m'
      : '${distanceKm.toStringAsFixed(1)} km';

  /// E.g. "15–20 min"
  String get etaLabel {
    final lo = etaMinutes;
    final hi = etaMinutes + 5;
    return '$lo–$hi min';
  }

  /// True when delivery is within the free-delivery radius
  bool get isFreeDelivery => deliveryFee == 0;
}

class DeliveryFeeService {
  // Free delivery threshold in km
  static const double _freeKmThreshold = 5.0;

  // Extra charge per km beyond the threshold
  static const double _extraChargePerKm = 10.0;

  // Base time (minutes) regardless of distance
  static const int _baseMinutes = 5;

  // Added minutes per km
  static const double _minutesPerKm = 2.0;

  /// Cached store location so we only fetch Firebase once per session.
  static double? _storeLat;
  static double? _storeLng;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Calculates [DeliveryInfo] for a user at [userLat]/[userLng].
  /// Fetches the store address from Firebase on first call.
  static Future<DeliveryInfo> calculate({
    required double userLat,
    required double userLng,
  }) async {
    final (storeLat, storeLng) = await _fetchStoreLocation();

    final distKm = _haversineKm(userLat, userLng, storeLat, storeLng);
    final fee = _calcFee(distKm);
    final eta = _calcEta(distKm);

    return DeliveryInfo(distanceKm: distKm, deliveryFee: fee, etaMinutes: eta);
  }

  /// Returns [DeliveryInfo] from a pre-parsed GPS string "lat, lng".
  /// Returns null when the string is malformed or fetch fails.
  static Future<DeliveryInfo?> fromGpsString(String? gpsCoords) async {
    if (gpsCoords == null || gpsCoords.isEmpty) return null;
    final parts = gpsCoords.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    try {
      return await calculate(userLat: lat, userLng: lng);
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<(double lat, double lng)> _fetchStoreLocation() async {
    if (_storeLat != null && _storeLng != null) {
      return (_storeLat!, _storeLng!);
    }

    final snap = await FirebaseDatabase.instance
        .ref('root/storeAdrs/adrs')
        .get();

    if (!snap.exists || snap.value == null) {
      throw Exception(
        'Store address not found in Firebase (root/storeAdrs/adrs)',
      );
    }

    final raw = snap.value.toString().trim();
    // Supports "lat,lng" or "lat, lng"
    final parts = raw.split(',');
    if (parts.length < 2) {
      throw Exception(
        'Store address format invalid: "$raw" (expected "lat, lng")',
      );
    }

    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) {
      throw Exception('Store address coordinates unparseable: "$raw"');
    }

    _storeLat = lat;
    _storeLng = lng;
    return (lat, lng);
  }

  static double _calcFee(double distKm) {
    if (distKm <= _freeKmThreshold) return 0;
    final extra = distKm - _freeKmThreshold;
    // Round up to the nearest 1 km for charging
    final extraCeil = extra.ceil().toDouble();
    return extraCeil * _extraChargePerKm;
  }

  static int _calcEta(double distKm) {
    return (_baseMinutes + (distKm * _minutesPerKm)).round();
  }

  /// Haversine great-circle distance in kilometres.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371; // Earth radius in km
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
