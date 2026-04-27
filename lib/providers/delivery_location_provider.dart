import 'package:flutter/foundation.dart';

/// Shared state for the user's current delivery location.
///
/// The [city] and [address] fields are shown in the [HeaderWidget] on
/// [ItemsPage]. They are updated whenever the user picks a location in
/// [CheckoutDetailsPage] via [LocationService.getCurrentLocation].
class DeliveryLocationProvider extends ChangeNotifier {
  String _city = 'My Location';
  String _address = 'Tap to set address';

  String get city => _city;
  String get address => _address;

  /// True once [update] has been called at least once.
  bool get hasLocation => _city != 'My Location';

  /// Called after the user picks / confirms a location from [LocationService].
  ///
  /// [formattedAddress] is the full reverse-geocoded string, e.g.
  /// "10th Cross, Madiwala, Bengaluru South, Karnataka, India".
  /// We split it into a short [city] (first meaningful part) and the full
  /// [address] for the subtitle.
  void update(String formattedAddress) {
    if (formattedAddress.trim().isEmpty) return;

    final parts = formattedAddress.split(',').map((s) => s.trim()).toList();

    // Best-effort: use the last significant city/area part for the title
    // and the first part (street/area) for the subtitle.
    // e.g. ["10th Cross", "Madiwala", "Bengaluru", "Karnataka", "India"]
    //   → city = "Bengaluru", address = "10th Cross, Madiwala"
    String city = formattedAddress;
    String address = formattedAddress;

    if (parts.length >= 3) {
      // City is typically the 3rd-from-last meaningful token before state/country.
      city = parts[parts.length - 3];
      // Address is the first two parts (street + locality).
      address = parts.take(2).join(', ');
    } else if (parts.length == 2) {
      city = parts[0];
      address = parts[1];
    } else {
      city = parts[0];
      address = parts[0];
    }

    _city = city.isEmpty ? formattedAddress : city;
    _address = address.isEmpty ? formattedAddress : address;
    notifyListeners();
  }
}
