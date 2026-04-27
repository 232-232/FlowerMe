import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../layout/responsive_layout.dart';
import '../../models/stock_variant_model.dart';
import '../../providers/stock_provider.dart';
import '../../models/product.dart' as app_models;
import '../../pages/product_details_page.dart';
import 'item_card_product.dart';
import 'item_details.dart';
import 'item_image.dart';
import '../../utils/share_helper.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/personalize_service.dart';
import 'package:provider/provider.dart';

class ItemCard extends StatefulWidget {
  const ItemCard({
    super.key,
    required this.product,
    required this.cartCount,
    required this.onQuantityChanged,
    this.onTap,
  });

  final ItemCardProduct product;
  final int cartCount;
  final void Function(app_models.Product product, int newQuantity, int variantIndex) onQuantityChanged;
  /// Optional override for tap – if provided, replaces default navigation to ProductDetailsPage.
  final VoidCallback? onTap;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late final Stream<List<StockVariantModel>> _stockStream;

  @override
  void initState() {
    super.initState();
    _stockStream = StockProvider.stockStream(widget.product.productCode);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockVariantModel>>(
      stream: _stockStream,
      builder: (context, snapshot) {
        final variants = snapshot.data ?? [];
        double displayPrice = widget.product.price;
        double displayOldPrice = widget.product.originalPrice;
        int displayDiscount = widget.product.effectiveDiscount;
        String displayUnitLabel = widget.product.weight;
        int quantity = -1; // -1 means unknown/unlimited fallback if no stock info

        // Determine the best variant once to use across all interactions
        final int selectedVariantIndex = variants.isNotEmpty 
            ? (variants.indexWhere((v) => v.quantity > 0) >= 0
                ? variants.indexWhere((v) => v.quantity > 0) 
                : 0) 
            : 0;

        final selectedVariant = variants.isNotEmpty ? variants[selectedVariantIndex] : null;

        if (selectedVariant != null) {
          displayPrice = selectedVariant.offerPrice;
          displayOldPrice = selectedVariant.mrp;
          displayDiscount = selectedVariant.discountPercent;
          displayUnitLabel = selectedVariant.label(widget.product.unit);
          quantity = selectedVariant.quantity;
        }

        // ONLY show "Coming Soon" if we have finished loading data and the price is still 0.
        // This prevents the flicker where every item shows "Coming Soon" for a split second.
        final bool isComingSoon = snapshot.connectionState != ConnectionState.waiting && displayPrice == 0;

        // Effective stock: total available minus items already in user's cart
        final int effectiveQuantity = quantity >= 0 ? (quantity - widget.cartCount) : -1;
        
        // Out of stock ONLY if ALL variants have zero quantity
        bool allVariantsOutOfStock = variants.isNotEmpty && variants.every((v) => v.quantity <= 0);
        final bool isOutOfStock = allVariantsOutOfStock && !isComingSoon;

        // If it cannot be purchased, clamp cart validation to prevent interactions
        // Check if THIS specific selected variant is out
        final bool disableAdd = isComingSoon || isOutOfStock || (effectiveQuantity >= 0 && effectiveQuantity == 0);

        return RepaintBoundary(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              splashColor: Colors.black.withValues(alpha: 0.04),
              highlightColor: Colors.black.withValues(alpha: 0.02),
              onLongPress: () {
                ShareHelper.shareItemCardProduct(widget.product);
                if (mounted) {
                  final phone = context.read<UserProfileProvider>().phone;
                  PersonalizeService.logShare(phone, widget.product.productCode);
                }
              },
              onTap: () {
                // If a custom tap handler is provided (e.g. age-gated category), use it.
                if (widget.onTap != null) {
                  widget.onTap!();
                  return;
                }


                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      product: widget.product.toAppModel(
                        displayPrice,
                        displayOldPrice,
                        displayDiscount,
                        variantId: selectedVariant?.variantId,
                        isOutOfStock: isOutOfStock,
                      ),
                      heroTag: 'grid_${widget.product.productCode}',
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 0.7),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.of(context).cardInnerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ItemImage(
                          product: widget.product,
                          displayDiscount: displayDiscount,
                          isComingSoon: isComingSoon,
                          isOutOfStock: isOutOfStock,
                          stockQuantity: effectiveQuantity,
                          heroTag: 'grid_${widget.product.productCode}',
                        ),
                      ),
                      ItemDetails(
                        product: widget.product,
                        cartCount: widget.cartCount,
                        disableAdd: disableAdd,
                        stockQuantity: effectiveQuantity,
                        displayPrice: displayPrice,
                        displayOldPrice: displayOldPrice,
                        displayDiscount: displayDiscount,
                        displayUnitLabel: displayUnitLabel,
                        onQuantityChanged: (price, oldPrice, discount, newQty) {
                          widget.onQuantityChanged(
                            widget.product.toAppModel(
                              price,
                              oldPrice,
                              discount,
                              variantId: selectedVariant?.variantId,
                              isOutOfStock: isOutOfStock,
                            ),
                            newQty,
                            selectedVariantIndex,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
