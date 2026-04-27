import '../../models/firebase_product_model.dart';
import '../../models/product.dart' as app_models;

/// Thin product model specifically for the ItemsPage cards.
class ItemCardProduct {
  const ItemCardProduct({
    required this.name,
    required this.weight,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.image,
    required this.productCode,
    required this.unit,
    this.details,
  });

  final String name;
  final String weight;
  final double price;
  final double originalPrice;
  final int discount;
  final String image;
  final String productCode;
  final String unit;
  final String? details;

  int get effectiveDiscount {
    if (discount > 0) return discount;
    if (originalPrice > 0 && originalPrice > price) {
      return ((originalPrice - price) / originalPrice * 100).round();
    }
    return 0;
  }

  ItemCardProduct copyWith({
    String? name,
    String? weight,
    double? price,
    double? originalPrice,
    int? discount,
    String? image,
    String? productCode,
    String? unit,
    String? details,
  }) => ItemCardProduct(
    name: name ?? this.name,
    weight: weight ?? this.weight,
    price: price ?? this.price,
    originalPrice: originalPrice ?? this.originalPrice,
    discount: discount ?? this.discount,
    image: image ?? this.image,
    productCode: productCode ?? this.productCode,
    unit: unit ?? this.unit,
    details: details ?? this.details,
  );

  factory ItemCardProduct.fromFirebase(FirebaseProductModel fb) => ItemCardProduct(
    name: fb.name,
    weight: fb.weight,
    price: fb.price,
    originalPrice: fb.originalPrice,
    discount: fb.discount,
    image: fb.picUrl ?? '',
    productCode: fb.code,
    unit: fb.unit,
    details: fb.details,
  );

  app_models.Product toAppModel(
    double finalPrice,
    double finalOldPrice,
    int finalDiscount, {
    String? variantId,
    bool isOutOfStock = false,
  }) {
    return app_models.Product(
      name: name,
      weight: weight,
      image: image,
      price: finalPrice,
      oldPrice: finalOldPrice,
      discount: finalDiscount,
      productCode: productCode,
      unit: unit,
      description: details,
      isOutOfStock: isOutOfStock,
      variants: variantId != null
          ? [
              app_models.ProductVariant(
                variantId: variantId,
                label: weight,
                price: finalPrice,
                oldPrice: finalOldPrice,
              )
            ]
          : null,
    );
  }
}
