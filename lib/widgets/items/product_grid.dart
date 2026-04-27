import 'package:flutter/material.dart';

import '../../layout/responsive_layout.dart';
import '../../models/product.dart';
import 'product_card.dart';

/// A responsive product grid that automatically switches column count,
/// cross-axis spacing, and card aspect-ratio based on screen width.
///
/// Breakpoints:
///   small  (< 360 dp) → 2 cols, compact aspect ratio
///   medium (360–599)  → 2 cols, standard aspect ratio
///   large  (≥ 600 dp) → 3 cols, wide aspect ratio
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.scrollController,
    this.onProductTap,
    this.onAddToCart,
    this.lastAddedProduct,
    this.bottomPadding = 0,
  });

  final List<Product> products;
  final ScrollController? scrollController;
  final void Function(Product product)? onProductTap;
  final void Function(Product product, Rect imageGlobalRect)? onAddToCart;
  final Product? lastAddedProduct;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final grid   = AppGridConfig.of(context);
    final sp     = AppSpacing.of(context);

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            sp.screenPadding,
            sp.cardPadding,
            sp.screenPadding,
            sp.cardPadding + bottomPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220.0,
              crossAxisSpacing: sp.gridSpacing,
              mainAxisSpacing:  sp.gridSpacing + 4,
              childAspectRatio: grid.childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  index: index,
                  onTap: onProductTap != null
                      ? () => onProductTap!(product)
                      : null,
                  onAddToCart: onAddToCart,
                  isLastAdded: lastAddedProduct != null &&
                      lastAddedProduct!.name == product.name,
                );
              },
              childCount: products.length,
            ),
          ),
        ),
      ],
    );
  }
}
