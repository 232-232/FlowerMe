import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../optimized_network_image.dart';


import '../../models/product.dart';
import '../../theme/app_colors.dart';
import 'add_button.dart';
import 'discount_badge.dart';

const double _kBorderRadius = 18.0;

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.isLastAdded = false,
    this.index = 0,
  });

  final Product product;
  final VoidCallback? onTap;
  final void Function(Product product, Rect imageGlobalRect)? onAddToCart;
  final bool isLastAdded;

  /// Grid index used for staggered entrance delay.
  final int index;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  void _onAddPressed() {
    widget.onAddToCart?.call(widget.product, _imageGlobalRect);
  }

  Rect get _imageGlobalRect {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return Rect.fromLTWH(0, 0, box.size.width, box.size.height)
        .shift(box.localToGlobal(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);
    final delay = Duration(milliseconds: 60 + widget.index * 50);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(_kBorderRadius),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Card body
              Container(
                padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_kBorderRadius),
                  border: widget.isLastAdded
                      ? Border.all(
                          color: appTheme.primaryAccent,
                          width: 2,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          key: _imageKey,
                          height: 120,
                          child: OptimizedNetworkImage(
                            imageUrl: widget.product.image,
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            fadeInDuration:
                                const Duration(milliseconds: 180),
                            placeholder: const _ImagePlaceholder(),
                            errorWidget: const _ImagePlaceholder(),
                            trackLogLabel: 'ProductCard',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.weight,
                      style: TextStyle(fontFamily: "PlusJakartaSans", 
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9CA3AF),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: "PlusJakartaSans", 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.product.oldPrice >
                                  widget.product.price)
                                Text(
                                  '₹${widget.product.oldPrice.toStringAsFixed(0)}',
                                  style: TextStyle(fontFamily: "PlusJakartaSans", 
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF9CA3AF),
                                    decoration:
                                        TextDecoration.lineThrough,
                                    decorationColor:
                                        const Color(0xFF9CA3AF),
                                  ),
                                ),
                              Text(
                                '₹${widget.product.price.toStringAsFixed(2)}',
                                style: TextStyle(fontFamily: "PlusJakartaSans", 
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer so the add button doesn't overlap price
                        const SizedBox(width: 44),
                      ],
                    ),
                  ],
                ),
              ),

              // Discount badge — top-left
              Positioned(
                top: -6,
                left: -6,
                child: DiscountBadge(discount: widget.product.discount),
              ),

              // Add / quantity button — bottom-right
              Positioned(
                bottom: -6,
                right: -6,
                child: AddButton(onPressed: _onAddPressed),
              ),
            ],
          ),
        ),
      ),
    )
        // Staggered entrance: slide up + fade in
        .animate(delay: delay)
        .slideY(
          begin: 0.18,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 320.ms, curve: Curves.easeOut);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: Color(0xFFD1D5DB),
        size: 34,
      ),
    );
  }
}
