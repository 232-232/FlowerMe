import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'optimized_network_image.dart';

import '../cart_scope.dart';
import '../cart_controller.dart';
import '../models/product.dart' as app_models;
import '../models/feed_product_model.dart';
import '../providers/home_feed_provider.dart';
import '../pages/product_details_page.dart';
import '../layout/responsive_layout.dart';
import '../theme/app_colors.dart';
import '../utils/share_helper.dart';

class BestSellersGrid extends StatelessWidget {
  const BestSellersGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeFeedProvider>(
      builder: (context, feedProvider, _) {
        // Resolve spacing/size INSIDE the builder so they always use the
        // Consumer's own context — avoids stale-closure undefined-enum
        // crashes in dart2js on Flutter Web.
        final s = AppSpacing.of(context);
        final size = context.screenSize;

        if (feedProvider.isLoading) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: s.sectionGap * 2),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final bestSellers = feedProvider.bestSellers;
        if (bestSellers.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final double maxExtent = size.pick(
          small: 160.0,
          medium: 180.0,
          large: 180.0,
        );

        final double aspectRatio = size.pick(
          small: 0.76,
          medium: 0.80,
          large: 0.84,
        );

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber[400],
                            size: size.isSmall ? 20 : 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'OUR BEST SELLERS',
                            style: TextStyle(
                              fontFamily: "PlusJakartaSans",
                              color: Color(0xFF111827),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              final title = 'Our Best Sellers';
                              final image = bestSellers.isNotEmpty
                                  ? bestSellers.first.picUrl
                                  : null;
                              ShareHelper.shareCategory(
                                title,
                                categoryCode: 'bestsellers',
                                categoryImage: image,
                              );
                            },
                            child: const Icon(
                              Icons.share_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: s.gridSpacing * 1.5),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: s.screenPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  crossAxisSpacing: s.gridSpacing,
                  mainAxisSpacing: s.gridSpacing,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = bestSellers[index];
                  return _BestSellerCard(feedProduct: product);
                }, childCount: bestSellers.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BestSellerCard extends StatefulWidget {
  const _BestSellerCard({required this.feedProduct});

  final FeedProductModel feedProduct;

  @override
  State<_BestSellerCard> createState() => _BestSellerCardState();
}

class _BestSellerCardState extends State<_BestSellerCard> {
  bool _pressed = false;

  void _navigateToDetails(BuildContext context) {
    final product = app_models.Product(
      name: widget.feedProduct.name,
      weight: widget.feedProduct.label,
      image: widget.feedProduct.picUrl,
      price: widget.feedProduct.offerPrice,
      oldPrice: widget.feedProduct.mrp,
      discount: widget.feedProduct.discountPercent,
      productCode: widget.feedProduct.productCode,
      unit: widget.feedProduct.unit,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsPage(
          product: product,
          heroTag: 'best_seller_${widget.feedProduct.productCode}',
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final CartController cart = CartScope.read(context);

    final app_models.Product product = app_models.Product(
      name: widget.feedProduct.name,
      weight: widget.feedProduct.label.isEmpty
          ? '1 unit'
          : widget.feedProduct.label,
      image: widget.feedProduct.picUrl,
      price: widget.feedProduct.offerPrice,
      oldPrice: widget.feedProduct.mrp,
      discount: widget.feedProduct.discountPercent,
      productCode: widget.feedProduct.productCode,
      unit: widget.feedProduct.unit,
    );

    cart.add(product, 1);
    cart.triggerBounce();
    cart.showAddedBar();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSpacing.of(context);
    final ts = AppTextScale.of(context);
    final size = context.screenSize;

    final double imgSize = size.pick(small: 70.0, medium: 85.0, large: 100.0);
    final double cardRadius = size.pick(small: 24.0, medium: 28.0, large: 32.0);

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => _navigateToDetails(context),
          onLongPress: () {
            final product = app_models.Product(
              name: widget.feedProduct.name,
              weight: widget.feedProduct.label,
              image: widget.feedProduct.picUrl,
              price: widget.feedProduct.offerPrice,
              oldPrice: widget.feedProduct.mrp,
              discount: widget.feedProduct.discountPercent,
              productCode: widget.feedProduct.productCode,
              unit: widget.feedProduct.unit,
            );
            ShareHelper.shareProduct(product);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: size.isLarge ? 1.0 : 0.7,
              ),
            ),
            padding: EdgeInsets.all(s.cardInnerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      child: Hero(
                        tag: 'best_seller_${widget.feedProduct.productCode}',
                        child: Container(
                        width: imgSize,
                        height: imgSize,
                        decoration: BoxDecoration(
                          color: Colors.white, // Pure white for a cleaner look
                          borderRadius: BorderRadius.circular(cardRadius * 0.7),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.feedProduct.picUrl.isNotEmpty
                            ? OptimizedNetworkImage(
                                imageUrl: widget.feedProduct.picUrl,
                                width: imgSize,
                                height: imgSize,
                                fit: BoxFit
                                    .contain, // Use contain to preserve product aspect ratio
                                placeholder: Icon(
                                  Icons.image_outlined,
                                  color: const Color(0xffE5E7EB),
                                  size: imgSize * 0.4,
                                ),
                                errorWidget: Icon(
                                  Icons.image_outlined,
                                  color: const Color(0xffE5E7EB),
                                  size: imgSize * 0.4,
                                ),
                              )
                            : Icon(
                                Icons.local_grocery_store_rounded,
                                color: const Color(0xffE5E7EB),
                                size: imgSize * 0.4,
                                   ),
                          ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: s.gridSpacing),
                Text(
                  widget.feedProduct.name,
                  maxLines: 2, // Allow 2 lines for better readability on tablet
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    color: const Color(0xFF111827),
                    fontSize: ts.body + 1,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.feedProduct.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    color: const Color(0xFF6B7280),
                    fontSize: ts.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: s.gridSpacing),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${widget.feedProduct.offerPrice.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: "PlusJakartaSans",
                            color: const Color(0xFF111827),
                            fontSize: ts.price,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _addToCart(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: size.isSmall ? 10 : 12,
                            vertical: size.isSmall ? 6 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeScope.themeOf(context).primaryAccent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeScope.themeOf(
                                  context,
                                ).primaryAccent.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'ADD',
                            style: TextStyle(
                              fontFamily: "PlusJakartaSans",
                              color: Colors.white,
                              fontSize: size.isSmall ? 9 : 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
