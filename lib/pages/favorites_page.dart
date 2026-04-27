import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/items_catalog.dart';
import '../models/product.dart';
import '../models/stock_variant_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/stock_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import 'product_details_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2EE),
      body: SafeArea(
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, appTheme),
                Expanded(
                  child: Selector<FavoritesProvider, List<Product>>(
                    selector: (_, f) => f.favoritesList,
                    builder: (context, favorites, child) {
                      if (favorites.isEmpty) {
                        return _buildEmptyState(appTheme);
                      }

                      return RepaintBoundary(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                          physics: kIsWeb
                              ? const ClampingScrollPhysics()
                              : const BouncingScrollPhysics(),
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FavoriteProductCard(
                                product: favorites[index],
                                appTheme: appTheme,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeData appTheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: appTheme.backgroundGradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Favourites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Selector<FavoritesProvider, int>(
            selector: (_, f) => f.count,
            builder: (_, count, child) => count > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count item${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeData appTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: appTheme.primaryAccent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 38,
              color: appTheme.primaryAccent.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No favourites yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2D2A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the heart icon on any product\nto add it to your favourites.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B6F6B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteProductCard extends StatelessWidget {
  const _FavoriteProductCard({
    required this.product,
    required this.appTheme,
  });

  final Product product;
  final AppThemeData appTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailsPage(product: product),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E6E2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEBECE8)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: OptimizedNetworkImage(
                    imageUrl: product.image,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFFBDBDBD)),
                    errorWidget: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFFBDBDBD)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E201E),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const SizedBox(height: 8),
                    StreamBuilder<List<StockVariantModel>>(
                      stream: StockProvider.stockStream(product.productCode),
                      builder: (context, snapshot) {
                        final stock = snapshot.data ?? [];
                        double activePrice = product.price;
                        double activeOldPrice = product.oldPrice;
                        int activeDiscount = product.discount;
                        String activeWeight = product.weight;

                        if (stock.isNotEmpty) {
                          // Try to find the first in-stock variant
                          final variant = stock.any((v) => v.quantity > 0)
                              ? stock.firstWhere((v) => v.quantity > 0)
                              : stock.first;
                          activePrice = variant.offerPrice;
                          activeOldPrice = variant.mrp;
                          activeDiscount = variant.discountPercent;
                          activeWeight = variant.label(product.unit);
                        }

                        // Fix zero price issue by showing a placeholder if still zero
                        final showPrice = activePrice > 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activeWeight.isNotEmpty) ...[
                              Text(
                                activeWeight,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF848884),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                Text(
                                  showPrice ? '₹${activePrice.toStringAsFixed(0)}' : 'Loading...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: showPrice ? appTheme.primaryAccent : Colors.grey,
                                  ),
                                ),
                                if (activeOldPrice > activePrice && showPrice) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${activeOldPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF9E9E9E),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                ],
                                if (activeDiscount > 0 && showPrice) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3D00).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$activeDiscount% OFF',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF3D00),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Heart button
              Selector<FavoritesProvider, bool>(
                selector: (_, f) => f.isFavorite(product.name),
                builder: (context, isFav, child) => GestureDetector(
                  onTap: () =>
                      context.read<FavoritesProvider>().toggle(product),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isFav
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFF4F5F1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border,
                      size: 18,
                      color: isFav ? Colors.red : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
