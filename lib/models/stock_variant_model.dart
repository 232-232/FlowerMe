// Model for a single stock variant stored at:
//   root/stock/{productCode}/{variantId}/
//
// Fields:
//   offerPrice  → selling / discounted price (num)
//   mrp         → maximum retail price / crossed-out price (num)
//   unitValue   → quantity amount, e.g. 500, 1, 250 (num)

class StockVariantModel {
  const StockVariantModel({
    required this.variantId,
    required this.offerPrice,
    required this.mrp,
    required this.unitValue,
    required this.quantity,
    required this.priorityTrending,
    required this.priorityBestseller,
    required this.prioritySuggestionBox,
  });

  /// The Firebase child key (e.g. "01", "02")
  final String variantId;

  /// Selling price (offerPrice from Firebase)
  final double offerPrice;

  /// Original / MRP price
  final double mrp;

  /// Quantity value (e.g. 500 for "500 ML", 1 for "1 KG")
  final double unitValue;

  /// Available stock quantity
  final int quantity;

  /// Priority for trending section (0 if not trending)
  final int priorityTrending;

  /// Priority for bestseller section (0 if not bestseller)
  final int priorityBestseller;

  /// Priority for suggestion box (0 if not in suggestion box)
  final int prioritySuggestionBox;

  /// Discount percentage calculated from offerPrice and mrp.
  int get discountPercent {
    if (mrp <= 0) return 0;
    final pct = ((mrp - offerPrice) / mrp * 100).round();
    return pct.clamp(0, 100);
  }

  /// Display label combining unitValue with a unit string.
  /// Handles conversion: 1000G -> 1KG, 1000ML -> 1L.
  String label(String unit) {
    double value = unitValue;
    String displayUnit = unit.toUpperCase();

    if (displayUnit == 'G' || displayUnit == 'GRAM' || displayUnit == 'GRAMS') {
      if (value >= 1000) {
        value = value / 1000;
        displayUnit = 'KG';
      }
    } else if (displayUnit == 'ML' || displayUnit == 'MILLILITRE' || displayUnit == 'ML.') {
      if (value >= 1000) {
        value = value / 1000;
        displayUnit = 'L';
      }
    }

    final valStr =
        value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '$valStr $displayUnit'.trim();
  }

  factory StockVariantModel.fromSnapshot(
    String variantId,
    dynamic rawData,
  ) {
    final data = Map<dynamic, dynamic>.from(rawData as Map);
    double readDouble(String key) {
      final v = data[key];
      double val = 0;
      if (v is num) {
        val = v.toDouble();
      } else if (v is String) {
        val = double.tryParse(v) ?? 0;
      }
      return val.isNaN ? 0.0 : val;
    }

    int readInt(String key) {
      final v = data[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return StockVariantModel(
      variantId: variantId,
      offerPrice: readDouble('offerPrice'),
      mrp: readDouble('mrp'),
      unitValue: readDouble('unitValue'),
      quantity: readInt('quantity'),
      priorityTrending: readInt('priorityTrending'),
      priorityBestseller: readInt('priorityBestseller'),
      prioritySuggestionBox: readInt('prioritySuggestionBox'),
    );
  }
}
