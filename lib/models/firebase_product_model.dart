// Model for a product stored at root/products/{productCode}/ in Firebase RTDB.
//
// Field names used (adjust here if DB keys differ):
//   name          → product display name
//   details       → short description / ingredients
//   pic           → image URL
//   categoryCode  → links this product to a root/category entry
//   price         → selling price (num)  [legacy fallback if no stock entry]
//   originalPrice → crossed-out MRP (num) [legacy fallback]
//   discount      → discount % (num)      [legacy fallback]
//   weight        → quantity label, e.g. "100G"
//   unit          → unit string, e.g. "KG", "ML", "G", "L", "PCS"

class FirebaseProductModel {
  const FirebaseProductModel({
    required this.code,
    required this.name,
    required this.categoryCode,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.weight,
    required this.unit,
    this.picUrl,
    this.details,
    this.labelName,
  });

  final String code;
  final String name;
  final String categoryCode;
  final double price;
  final double originalPrice;
  final int discount;
  final String weight;
  /// Unit string from root/products, e.g. "KG", "ML", "G", "L", "PCS".
  final String unit;
  final String? picUrl;
  final String? details;
  final String? labelName;

  factory FirebaseProductModel.fromSnapshot(
    String code,
    dynamic rawData,
  ) {
    final data = Map<dynamic, dynamic>.from(rawData as Map);
    // ── Helper: safely read a num field ──────────────────────────────────────
    double readDouble(String key, double fallback) {
      final v = data[key];
      double val = fallback;
      if (v is num) {
        val = v.toDouble();
      } else if (v is String) {
        val = double.tryParse(v) ?? fallback;
      }
      return val.isNaN ? fallback : val;
    }

    int readInt(String key, int fallback) {
      final v = data[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final name = (data['name'] as String?) ?? code;
    final categoryCode = (data['categoryCode'] as String?) ?? '';
    final weight = (data['weight'] as String?) ?? '';
    final unit = (data['unit'] as String?) ?? '';
    final picUrl = data['pic'] as String?;
    final details = data['details'] as String?;
    final labelName = data['labelName'] as String?;
    final price = readDouble('price', 0);
    final originalPrice = readDouble('originalPrice', price);
    final discount = readInt('discount', 0);

    return FirebaseProductModel(
      code: code,
      name: name,
      categoryCode: categoryCode,
      price: price,
      originalPrice: originalPrice,
      discount: discount,
      weight: weight,
      unit: unit,
      picUrl: picUrl,
      details: details,
      labelName: labelName,
    );
  }
}
