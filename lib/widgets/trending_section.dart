import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'optimized_network_image.dart';

import '../cart_scope.dart';
import '../cart_controller.dart';
import '../models/product.dart' as app_models;
import '../models/feed_product_model.dart';
import '../providers/home_feed_provider.dart';
import '../pages/product_details_page.dart';
import '../theme/app_colors.dart';
import '../utils/share_helper.dart';

class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeFeedProvider>(
      builder: (context, feedProvider, _) {
        if (feedProvider.isLoading) {
          return const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final trendingProducts = feedProvider.trendingProducts;
        if (trendingProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppThemeScope.themeOf(context).primaryAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TRENDING NOW',
                    style: TextStyle(
                      fontFamily: "PlusJakartaSans",
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      final title = 'Trending products';
                      final image = trendingProducts.isNotEmpty
                          ? trendingProducts.first.picUrl
                          : null;
                      ShareHelper.shareCategory(
                        title,
                        categoryCode: 'trending',
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
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: trendingProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final product = trendingProducts[index];
                  return _TrendingCard(feedProduct: product);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrendingCard extends StatefulWidget {
  const _TrendingCard({required this.feedProduct});

  final FeedProductModel feedProduct;

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
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
          heroTag: 'trending_${widget.feedProduct.productCode}',
        ),
      ),
    );
  }

  void _addToCart(BuildContext context) {
    final CartController cart = CartScope.read(context);

    final app_models.Product product = app_models.Product(
      name: widget.feedProduct.name,
      weight: widget.feedProduct.label,
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
    final discount = widget.feedProduct.discountPercent;

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            // FIX 16: Removed BoxShadow blur to restore 60fps on Home Page
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.7),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              splashColor: Colors.black.withOpacity(0.04),
              highlightColor: Colors.black.withOpacity(0.02),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (discount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffF97316),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: const TextStyle(
                            fontFamily: "PlusJakartaSans",
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const SizedBox(
                        height: 19,
                      ), // Provide consistent height to match badge
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xffEEF2FF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Hero(
                            tag: 'trending_${widget.feedProduct.productCode}',
                            child: widget.feedProduct.picUrl.isNotEmpty
                                ? OptimizedNetworkImage(
                                    imageUrl: widget.feedProduct.picUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: const Icon(
                                      Icons.image_outlined,
                                      color: Color(0xff4B5563),
                                      size: 34,
                                    ),
                                    errorWidget: const Icon(
                                      Icons.image_outlined,
                                      color: Color(0xff4B5563),
                                      size: 34,
                                    ),
                                  )
                                : const Icon(
                                    Icons.local_grocery_store_rounded,
                                    color: Color(0xff4B5563),
                                    size: 34,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.feedProduct.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "PlusJakartaSans",
                        color: Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '₹${widget.feedProduct.offerPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: "PlusJakartaSans",
                            color: Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            splashColor: Colors.white.withOpacity(0.3),
                            highlightColor: Colors.white.withOpacity(0.1),
                            onTap: () => _addToCart(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppThemeScope.themeOf(
                                  context,
                                ).primaryAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
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
        ),
      ),
    );
  }
}
