/// Model for a saved delivery address.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.gpsCoords,
    this.isDefault = false,
  });

  /// Unique identifier (UUID-style string created once).
  final String id;

  /// Display label: 'home', 'work', 'other', or a custom string.
  final String label;

  /// Full formatted address text.
  final String fullAddress;

  /// Optional raw GPS coords string "lat, lng".
  final String? gpsCoords;

  /// Whether this address is the active/default one.
  final bool isDefault;

  // ── Icon helper ──────────────────────────────────────────────────────────

  static String iconNameFor(String label) {
    switch (label.toLowerCase()) {
      case 'home':   return 'home';
      case 'work':   return 'work';
      default:       return 'other';
    }
  }

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullAddress': fullAddress,
        if (gpsCoords != null) 'gpsCoords': gpsCoords,
        'isDefault': isDefault,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String,
        fullAddress: json['fullAddress'] as String,
        gpsCoords: json['gpsCoords'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  SavedAddress copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? gpsCoords,
    bool? isDefault,
    bool clearGps = false,
  }) =>
      SavedAddress(
        id: id ?? this.id,
        label: label ?? this.label,
        fullAddress: fullAddress ?? this.fullAddress,
        gpsCoords: clearGps ? null : (gpsCoords ?? this.gpsCoords),
        isDefault: isDefault ?? this.isDefault,
      );
}
