import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/favorites_provider.dart';
import '../optimized_network_image.dart';
import 'item_card_product.dart';

class ItemImage extends StatefulWidget {
  const ItemImage({
    super.key,
    required this.product,
    required this.displayDiscount,
    this.isComingSoon = false,
    this.isOutOfStock = false,
    this.stockQuantity = -1,
    this.heroTag,
  });

  final ItemCardProduct product;
  final int displayDiscount;
  final bool isComingSoon;
  final bool isOutOfStock;
  final int stockQuantity;
  final String? heroTag;

  @override
  State<ItemImage> createState() => _ItemImageState();
}

class _ItemImageState extends State<ItemImage> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool isDimmed = widget.isComingSoon || widget.isOutOfStock;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovering ? 1.03 : 1.0,
        curve: Curves.easeOut,
        child: Stack(
          children: [
            // ── Image container ─────────────────────────────────────────────
            Hero(
              tag: widget.heroTag ?? 'product_image_${widget.product.productCode}',
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: OptimizedNetworkImage(
                  imageUrl: widget.product.image,
                  width: 150,
                  height: 100,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  trackLogLabel: 'ItemsPage_Image',
                ),
              ),
            ),

            // ── Dimming overlay (out-of-stock / coming-soon) ─────────────────
            // Kept as a Stack sibling OUTSIDE the Hero so the flight is clean.
            if (isDimmed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

            // ── Status Badge ─────────────────────────────────────────────────
            if (isDimmed)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width * 0.02,
                      vertical: MediaQuery.sizeOf(context).height * 0.005,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isComingSoon
                          ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                          : const Color(0xFFEF4444).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.isComingSoon ? 'Coming Soon' : 'Out of Stock',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Discount badge — top-left ────────────────────────────────────
            if (widget.displayDiscount > 0 && !isDimmed)
              Positioned(
                top: 0,
                left: 0,
                child: RepaintBoundary(
                  child: _OfferBadge(label: '${widget.displayDiscount}% OFF'),
                ),
              ),

            // ── Heart icon — top-right ───────────────────────────────────────
            Positioned(
              top: 0,
              right: 0,
              child: Selector<FavoritesProvider, bool>(
                selector: (_, favs) => favs.isFavorite(widget.product.name),
                builder: (context, isFavorite, _) => GestureDetector(
                  onTap: () {
                    context.read<FavoritesProvider>().toggle(
                          widget.product.toAppModel(
                            widget.product.price,
                            widget.product.originalPrice,
                            widget.displayDiscount,
                          ),
                        );
                  },
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 5,
                      right: 7,
                      left: 10,
                      bottom: 10,
                    ),
                    color: Colors.transparent,
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: isFavorite ? Colors.red : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),

            // ── Low-stock badge — bottom centre ─────────────────────────────
            if (widget.stockQuantity > 0 &&
                widget.stockQuantity <= 3 &&
                !isDimmed)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      'Only ${widget.stockQuantity} left',
                      style: const TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge({required this.label});
  final String label;

  static const _style = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Text(label, style: _style),
    );
  }
}
