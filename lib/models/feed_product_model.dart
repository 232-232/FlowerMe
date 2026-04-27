// Model representing a product ready to be displayed in a feed (like Trending or Best Sellers).
// It combines essential data from both the root/products and root/stock nodes.

class FeedProductModel {
  const FeedProductModel({
    required this.productCode,
    required this.variantId,
    required this.name,
    required this.picUrl,
    required this.offerPrice,
    required this.mrp,
    required this.unitValue,
    required this.unit,
    required this.priorityTrending,
    required this.priorityBestseller,
    this.labelName,
  });

  final String productCode;
  final String variantId;
  final String name;
  final String picUrl;
  final double offerPrice;
  final double mrp;
  final double unitValue;
  final String unit;
  final int priorityTrending;
  final int priorityBestseller;
  final String? labelName;

  /// Discount percentage calculated from offerPrice and mrp.
  int get discountPercent {
    if (mrp <= 0) return 0;
    final pct = ((mrp - offerPrice) / mrp * 100).round();
    return pct.clamp(0, 100);
  }

  /// Display label combining unitValue with a unit string.
  String get label {
    final valStr =
        unitValue == unitValue.roundToDouble()
            ? unitValue.toInt().toString()
            : unitValue.toString();
    return '$valStr $unit'.trim();
  }
}
