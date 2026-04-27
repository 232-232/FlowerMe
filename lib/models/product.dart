import 'package:flutter/foundation.dart';

@immutable
@immutable
class ProductVariant {
  const ProductVariant({
    required this.variantId,
    required this.label,
    required this.price,
    required this.oldPrice,
  });

  final String variantId;
  final String label;
  final double price;
  final double oldPrice;

  Map<String, dynamic> toMap() => {
        'variantId': variantId,
        'label': label,
        'price': price,
        'oldPrice': oldPrice,
      };

  factory ProductVariant.fromMap(Map<String, dynamic> map) => ProductVariant(
        variantId: map['variantId'] as String,
        label: map['label'] as String,
        price: (map['price'] as num).toDouble(),
        oldPrice: (map['oldPrice'] as num).toDouble(),
      );
}

@immutable
class Product {
  const Product({
    required this.name,
    required this.weight,
    required this.image,
    required this.price,
    required this.oldPrice,
    required this.discount,
    this.productCode = '',
    this.unit = '',
    this.description,
    this.variants,
    this.isOutOfStock = false,
  });

  final String name;
  final String weight;
  final String image;
  final double price;
  final double oldPrice;
  final int discount;
  final String productCode;
  final String unit;
  final String? description;
  final List<ProductVariant>? variants;
  final bool isOutOfStock;

  Map<String, dynamic> toMap() => {
        'name': name,
        'weight': weight,
        'image': image,
        'price': price,
        'oldPrice': oldPrice,
        'discount': discount,
        'productCode': productCode,
        'unit': unit,
        'description': description,
        'variants': variants?.map((v) => v.toMap()).toList(),
        'isOutOfStock': isOutOfStock,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        name: map['name'] as String,
        weight: map['weight'] as String,
        image: map['image'] as String,
        price: (map['price'] as num).toDouble(),
        oldPrice: (map['oldPrice'] as num).toDouble(),
        discount: (map['discount'] as num).toInt(),
        productCode: map['productCode'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        description: map['description'] as String?,
        variants: (map['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
            .toList(),
        isOutOfStock: map['isOutOfStock'] as bool? ?? false,
      );
}
