import 'package:flutter/foundation.dart';

import 'product.dart';

/// A single line in the cart: product, chosen variant, and quantity.
@immutable
class CartEntry {
  const CartEntry({
    required this.product,
    required this.quantity,
    this.variantIndex = 0,
  });

  final Product product;
  final int quantity;
  final int variantIndex;

  double get unitPrice {
    if (product.variants != null &&
        product.variants!.isNotEmpty &&
        variantIndex < product.variants!.length) {
      return product.variants![variantIndex].price;
    }
    return product.price;
  }

  double get lineTotal => unitPrice * quantity;

  String get variantLabel {
    if (product.variants != null &&
        product.variants!.isNotEmpty &&
        variantIndex < product.variants!.length) {
      return product.variants![variantIndex].label;
    }
    return product.weight;
  }
}
