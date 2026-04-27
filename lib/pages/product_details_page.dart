import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../cart_scope.dart';
import '../models/product.dart';
import '../models/stock_variant_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/stock_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import 'cart_page.dart';
import '../widgets/cart_edit_bottom_sheet.dart';
import '../utils/share_helper.dart';
import '../providers/user_profile_provider.dart';
import '../services/personalize_service.dart';
import '../models/firebase_product_model.dart';
import '../services/search_service.dart';

// ─── Neutral palette (never theme-driven) ───────────────────────────────────
const Color _ink = Color(0xFF1A1A2E);
const Color _inkLight = Color(0xFF555571);
const Color _surface = Color(0xFFF8F9FA);
const Color _border = Color(0xFFE8EAED);
const Color _redSoft = Color(0xFFFF5252);
const Color _gold = Color(0xFFFFB300);
const Color _priceMuted = Color(0xFFADB5BD);

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product, this.heroTag});
  final Product product;
  final String? heroTag;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage>
    with SingleTickerProviderStateMixin {
  int _selectedVariantIndex = 0;
  bool _descriptionExpanded = false;

  // Stock variants streamed from Firebase
  List<StockVariantModel> _stockVariants = const [];
  bool _stockLoading = true;
  StreamSubscription<List<StockVariantModel>>? _stockSubscription;

  // ── Stock-derived computed state ──────────────────────────────────────────

  /// Available quantity for the currently selected variant.
  /// Returns -1 when stock data hasn't loaded yet (treat as unlimited).
  int get _currentVariantQuantity {
    if (_stockVariants.isEmpty) return -1;
    if (_selectedVariantIndex < _stockVariants.length) {
      return _stockVariants[_selectedVariantIndex].quantity;
    }
    return _stockVariants.first.quantity;
  }

  /// Effective stock: total available minus items already in user's cart
  int _getEffectiveStock(int cartQty) {
    if (_currentVariantQuantity == -1) return -1;
    return (_currentVariantQuantity - cartQty).clamp(0, 999);
  }

  /// True when the selected variant price is 0 (not yet for sale) and stock is fully loaded.
  bool get _isComingSoon => !_stockLoading && _currentVariant.price == 0;

  bool _isOutOfStock(int cartCount) {
    if (_stockLoading) return widget.product.isOutOfStock;
    final effectiveStock = _getEffectiveStock(cartCount);
    return !_isComingSoon && effectiveStock == 0;
  }

  @override
  void initState() {
    super.initState();
    // Delay heavy data parsing by 300ms so the route transition animation is 100% jank-free
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fetchStock();
    });
  }

  void _fetchStock() {
    final productCode = widget.product.productCode;
    if (productCode.isEmpty) {
      setState(() => _stockLoading = false);
      return;
    }
    _stockSubscription = StockProvider.stockStream(productCode).listen((
      variants,
    ) {
      if (mounted) {
        setState(() {
          _stockVariants = variants;
          _stockLoading = false;

          // If a specific variant was passed in the initial product model, select it.
          // Otherwise, select the first in-stock variant by default.
          final String? initialVariantId =
              widget.product.variants?.isNotEmpty == true
              ? widget.product.variants!.first.variantId
              : null;

          if (initialVariantId != null) {
            final idx = variants.indexWhere(
              (v) => v.variantId == initialVariantId,
            );
            if (idx >= 0) {
              _selectedVariantIndex = idx;
            }
          } else if (_selectedVariantIndex == 0 && variants.isNotEmpty) {
            // If no specific variant target, default to first available
            final availableIdx = variants.indexWhere((v) => v.quantity > 0);
            if (availableIdx >= 0) {
              _selectedVariantIndex = availableIdx;
            }
          }

          // Clamp selected index if variants count changed or fallback failed
          if (_selectedVariantIndex >= _variantsFromStock(variants).length) {
            _selectedVariantIndex = 0;
          }
        });
      }
    });
  }

  /// Build _VariantData list from live Firebase stock variants.
  /// Falls back to a single entry from the product itself if no stock.
  List<_VariantData> _variantsFromStock(List<StockVariantModel> stock) {
    if (stock.isNotEmpty) {
      final unit = widget.product.unit;
      return stock.map((s) {
        final lbl = s.label(unit);
        return _VariantData(
          variantId: s.variantId,
          label: lbl,
          subtitle: '',
          price: s.offerPrice,
          oldPrice: s.mrp,
          quantity: s.quantity,
          discountPercent: s.discountPercent,
        );
      }).toList();
    }
    // Fallback: use product base price/oldPrice
    final p = widget.product;
    int pct = p.discount;
    if (pct == 0 && p.oldPrice > 0 && p.oldPrice > p.price) {
      pct = ((p.oldPrice - p.price) / p.oldPrice * 100).round();
    }
    return [
      _VariantData(
        variantId: 'base',
        label: p.weight.isNotEmpty ? p.weight : '1 Unit',
        subtitle: '',
        price: p.price,
        oldPrice: p.oldPrice,
        quantity: 9999,
        discountPercent: pct,
      ),
    ];
  }

  List<_VariantData> get _variants => _variantsFromStock(_stockVariants);

  _VariantData get _currentVariant {
    final v = _variants;
    if (_selectedVariantIndex < v.length) return v[_selectedVariantIndex];
    return v.first;
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }

  void _setCartVariantQuantity(
    BuildContext ctx,
    int newQuantity,
    int totalStock,
  ) {
    if (totalStock >= 0 && newQuantity > totalStock) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Sorry, only ${totalStock >= 0 ? totalStock : 0} quantity left',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final cart = CartScope.read(ctx);

    final productVariants = _variants
        .map(
          (v) => ProductVariant(
            variantId: v.variantId,
            label: v.label,
            price: v.price,
            oldPrice: v.oldPrice,
          ),
        )
        .toList();

    final productToCart = Product(
      name: widget.product.name,
      weight: widget.product.weight,
      image: widget.product.image,
      price: widget.product.price,
      oldPrice: widget.product.oldPrice,
      discount: widget.product.discount,
      productCode: widget.product.productCode,
      unit: widget.product.unit,
      description: widget.product.description,
      variants: productVariants,
    );

    cart.setQuantity(
      productToCart,
      newQuantity,
      variantIndex: _selectedVariantIndex,
    );
    if (newQuantity > 0) {
      cart.setLastAdded(productToCart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _Header(product: widget.product),
            // ── Scrollable content ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
                      listenable: CartScope.read(context),
                      builder: (context, _) {
                        final cart = CartScope.read(context);
                        final cartCount = cart.entries
                            .where(
                              (e) =>
                                  e.product.productCode ==
                                  widget.product.productCode,
                            )
                            .fold(0, (sum, e) => sum + e.quantity);
                        final isOutOfStock = _isOutOfStock(cartCount);

                        return _ProductImage(
                          imageUrl: widget.product.image,
                          productCode: widget.product.productCode,
                          heroTag: widget.heroTag,
                          isComingSoon: _isComingSoon,
                          isOutOfStock: isOutOfStock,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _TitleRow(product: widget.product),
                    const SizedBox(height: 12),
                    _PriceRow(
                      variant: _currentVariant,
                      isLoading: _stockLoading,
                    ),
                    if (_variants.length > 1) ...[
                      const SizedBox(height: 20),
                      _VariantSelector(
                        variants: _variants,
                        selectedIndex: _selectedVariantIndex,
                        onSelect: (i) =>
                            setState(() => _selectedVariantIndex = i),
                        isLoading: _stockLoading,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Description(
                      text: widget.product.description ??
                          'Premium quality product. Pack size: ${_currentVariant.label}. '
                              'Circular Power Bristles, Easy-to-Grip Handle, Removes Stains. '
                              'Specially designed for sensitive gums.',
                      expanded: _descriptionExpanded,
                      onToggle: () => setState(
                        () => _descriptionExpanded = !_descriptionExpanded,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SuggestedItems(currentProductCode: widget.product.productCode),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // ── Add-to-Cart bar ───────────────────────────────────────────────
            ListenableBuilder(
              listenable: CartScope.read(context),
              builder: (context, _) {
                final cart = CartScope.read(context);
                final cartCountOverall = cart.entries
                    .where(
                      (e) =>
                          e.product.productCode == widget.product.productCode,
                    )
                    .fold(0, (sum, e) => sum + e.quantity);
                final variantCartQty = cart.entries
                    .where(
                      (e) =>
                          e.product.productCode == widget.product.productCode &&
                          e.variantIndex == _selectedVariantIndex,
                    )
                    .fold(0, (sum, e) => sum + e.quantity);

                final stockQty = _currentVariantQuantity;
                final isOutOfStock = _isOutOfStock(cartCountOverall);
                final canPurchase = !_isComingSoon && !isOutOfStock;
                final atStockLimit =
                    canPurchase &&
                    stockQty >= 0 &&
                    cartCountOverall >= stockQty;
                final isDisabled = !canPurchase || atStockLimit;
                final maxMore = canPurchase && stockQty >= 0
                    ? (stockQty - cartCountOverall).clamp(0, 9999)
                    : 9999;
                return _AddToCartBar(
                  quantity: variantCartQty,
                  isDisabled: isDisabled && variantCartQty == 0,
                  onDecrement: () {
                    HapticFeedback.lightImpact();
                    _setCartVariantQuantity(
                      context,
                      variantCartQty - 1,
                      stockQty,
                    );
                  },
                  onIncrement: () {
                    HapticFeedback.lightImpact();
                    if (maxMore > 0) {
                      _setCartVariantQuantity(
                        context,
                        variantCartQty + 1,
                        stockQty,
                      );
                    }
                  },
                  maxMore: maxMore,
                  stockQty: stockQty,
                  onAddToCart: () {
                    HapticFeedback.mediumImpact();
                    _setCartVariantQuantity(
                      context,
                      variantCartQty + 1,
                      stockQty,
                    );
                  },
                );
              },
            ),
            // ── Checkout bar (synced) ───────────────────────────────────────
            ListenableBuilder(
              listenable: CartScope.read(context),
              builder: (context, _) {
                final cart = CartScope.read(context);
                if (cart.count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _CheckoutBar(
                    itemCount: cart.count,
                    total: cart.totalPrice,
                    onClearCart: () => CartEditBottomSheet.show(context, cart),
                    onViewCart: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CartPage(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

// ─── Header ─────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartScope.of(context),
      builder: (context, _) {
        final cart = CartScope.of(context);
        final count = cart.count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _NavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              _NavButton(
                icon: Icons.home_rounded,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              const Spacer(),
              _NavButton(
                icon: Icons.share_rounded,
                onTap: () {
                  ShareHelper.shareProduct(product);
                  if (context.mounted) {
                    final phone = context.read<UserProfileProvider>().phone;
                    PersonalizeService.logShare(phone, product.productCode);
                  }
                },
              ),
              const SizedBox(width: 10),
              _CartBadgeButton(
                count: count,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CartPage()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: _ink),
      ),
    );
  }
}

class _CartBadgeButton extends StatelessWidget {
  const _CartBadgeButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 20,
              color: _ink,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _redSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Product Image ─────────────────────────────────────────────────────────
class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.productCode,
    this.heroTag,
    this.isComingSoon = false,
    this.isOutOfStock = false,
  });

  final String imageUrl;
  final String productCode;
  final String? heroTag;
  final bool isComingSoon;
  final bool isOutOfStock;

  bool get _isDimmed => isComingSoon || isOutOfStock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Hero(
          tag: heroTag ?? 'product_image_$productCode',
          child: Container(
            width: double.infinity,
            height: 230,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: OptimizedNetworkImage(
              imageUrl: imageUrl,
              width: 400,
              height: 230,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: _placeholder(),
              errorWidget: _placeholder(),
              trackLogLabel: 'ProductDetailsPage',
            ),
          ),
        ),

        // ── Dimming overlay (outside Hero — never touches the flight) ──
        if (_isDimmed)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

        // ── Centered status badge overlay ──────────────────────────────
        if (_isDimmed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isComingSoon
                  ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                  : const Color(0xFFEF4444).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              isComingSoon ? 'Coming Soon' : 'Out of Stock',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 56, color: _border),
        const SizedBox(height: 8),
        Text(
          'No image',
          style: TextStyle(
            fontFamily: "PlusJakartaSans",
            color: _priceMuted,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

// ─── Title Row ────────────────────────────────────────────────────────────
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  fontFamily: "PlusJakartaSans",
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: _gold),
                  const SizedBox(width: 3),
                  Text(
                    '4.8  ·  2.3k reviews',
                    style: TextStyle(
                      fontFamily: "PlusJakartaSans",
                      fontSize: 12,
                      color: _inkLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Selector<FavoritesProvider, bool>(
          selector: (_, favs) => favs.isFavorite(product.name),
          builder: (context, isFavorite, _) => GestureDetector(
            onTap: () {
              context.read<FavoritesProvider>().toggle(product);
              if (context.mounted) {
                final phone = context.read<UserProfileProvider>().phone;
                PersonalizeService.logFavorite(
                  phone,
                  product.productCode,
                  !isFavorite,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isFavorite ? const Color(0xFFFFEBEB) : _surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 22,
                color: isFavorite ? _redSoft : _inkLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Price Row ────────────────────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.variant, this.isLoading = false});
  final _VariantData variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (isLoading && variant.price == 0)
              Container(
                width: 100,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            else ...[
              Text(
                '₹${variant.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: "PlusJakartaSans",
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              if (variant.oldPrice > variant.price) ...[
                Text(
                  '₹${variant.oldPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    fontSize: 16,
                    color: _priceMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: _priceMuted,
                  ),
                ),
                if (variant.discountPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${variant.discountPercent}% OFF',
                      style: TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _redSoft,
                      ),
                    ),
                  ),
              ],
            ],
            const _FastDeliveryBadge(),
          ],
        ),
        const SizedBox(height: 10),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: variant.quantity <= 0
                  ? Colors.red.withValues(alpha: 0.08)
                  : variant.quantity <= 3
                  ? Colors.orange.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: variant.quantity <= 0
                    ? Colors.red.withValues(alpha: 0.15)
                    : variant.quantity <= 3
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: variant.quantity <= 0
                        ? Colors.red.shade600
                        : variant.quantity <= 3
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  variant.quantity <= 0
                      ? 'OUT OF STOCK'
                      : variant.quantity <= 3
                      ? 'ONLY ${variant.quantity} LEFT'
                      : '${variant.quantity} LEFT',
                  style: TextStyle(
                    fontFamily: "PlusJakartaSans",
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: variant.quantity <= 0
                        ? Colors.red.shade700
                        : variant.quantity <= 3
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FastDeliveryBadge extends StatelessWidget {
  const _FastDeliveryBadge();

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final accent = theme.primaryAccent;
    final chipBg = theme.gridContainerBg;
    final secondary = theme.secondaryAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: secondary),
          const SizedBox(width: 3),
          Text(
            'Fast Delivery',
            style: TextStyle(
              fontFamily: "PlusJakartaSans",
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Variant Selector ────────────────────────────────────────────────────
class _VariantSelector extends StatelessWidget {
  const _VariantSelector({
    required this.variants,
    required this.selectedIndex,
    required this.onSelect,
    this.isLoading = false,
  });
  final List<_VariantData> variants;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final accent = theme.primaryAccent;
    final chipBg = theme.gridContainerBg;
    final secondary = theme.secondaryAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Pack',
          style: TextStyle(
            fontFamily: "PlusJakartaSans",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          // Shimmer placeholder while stock loads from Firebase
          Row(
            children: List.generate(2, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 0 ? 10 : 0),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              );
            }),
          )
        else
          Row(
            children: List.generate(variants.length, (i) {
              final v = variants[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < variants.length - 1 ? 10 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? chipBg : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? accent : _border,
                          width: selected ? 1.8 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkmark dot
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? accent : Colors.white,
                              border: Border.all(
                                color: selected ? accent : _border,
                                width: 2,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            v.label,
                            style: TextStyle(
                              fontFamily: "PlusJakartaSans",
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? secondary : _ink,
                            ),
                          ),
                          if (v.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              v.subtitle,
                              style: TextStyle(
                                fontFamily: "PlusJakartaSans",
                                fontSize: 10,
                                color: selected
                                    ? secondary.withValues(alpha: 0.5)
                                    : _inkLight.withValues(alpha: 0.5),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '₹${v.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontFamily: "PlusJakartaSans",
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? secondary : _ink,
                            ),
                          ),
                          if (v.oldPrice > v.price)
                            Text(
                              '₹${v.oldPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontFamily: "PlusJakartaSans",
                                fontSize: 10,
                                color: _priceMuted,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: _priceMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

// ─── Description ─────────────────────────────────────────────────────────
class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    const int maxLines = 3;
    final needsMore = text.length > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About the Product',
          style: TextStyle(
            fontFamily: "PlusJakartaSans",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: expanded ? null : maxLines,
          overflow: expanded ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "PlusJakartaSans",
            fontSize: 14,
            color: _inkLight,
            height: 1.6,
          ),
        ),
        if (needsMore) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Show less' : 'Read more',
              style: TextStyle(
                fontFamily: "PlusJakartaSans",
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Add to Cart Bar ──────────────────────────────────────────────────────
class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.quantity,
    required this.isDisabled,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAddToCart,
    required this.maxMore,
    required this.stockQty,
  });

  final int quantity;
  final bool isDisabled;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAddToCart;
  final int maxMore;
  final int stockQty;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final accent = theme.primaryAccent;
    final secondary = theme.secondaryAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            child: quantity > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Opacity(
                      opacity: isDisabled ? 0.45 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepperBtn(
                              icon: Icons.remove_rounded,
                              onTap: onDecrement,
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '$quantity',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ),
                            _StepperBtn(
                              icon: Icons.add_rounded,
                              onTap: onIncrement,
                              accent: maxMore > 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isDisabled ? null : onAddToCart,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 52,
                decoration: BoxDecoration(
                  gradient: isDisabled
                      ? null
                      : LinearGradient(
                          colors: [accent, secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isDisabled ? const Color(0xFFE5E7EB) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      size: 20,
                      color: isDisabled
                          ? const Color(0xFF9CA3AF)
                          : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDisabled
                            ? const Color(0xFF9CA3AF)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final chipBg = theme.gridContainerBg;
    final secondary = theme.secondaryAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 48,
        decoration: BoxDecoration(
          color: accent ? chipBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: accent ? secondary : _inkLight),
      ),
    );
  }
}

// ─── Checkout Bar (animated in/out) ──────────────────────────────────────
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.itemCount,
    required this.total,
    required this.onClearCart,
    required this.onViewCart,
  });

  final int itemCount;
  final double total;
  final VoidCallback onClearCart;
  final VoidCallback onViewCart;

  static final _itemsStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.7,
  );
  static final _totalLabelStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
    letterSpacing: 0.6,
  );
  static final _totalStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    return SafeArea(
      minimum: EdgeInsets.zero,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.65),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onClearCart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 2),
                    Text('$itemCount ITEMS', style: _itemsStyle),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('TOTAL', style: _totalLabelStyle),
                  const SizedBox(height: 2),
                  Text('₹${total.toStringAsFixed(2)}', style: _totalStyle),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onViewCart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VIEW CART',
                      style: TextStyle(
                        fontFamily: "PlusJakartaSans",
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Suggested Items ────────────────────────────────────────────────────────
class _SuggestedItems extends StatelessWidget {
  const _SuggestedItems({required this.currentProductCode});
  final String currentProductCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Similar Products',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 156,
          child: StreamBuilder<Map<String, FirebaseProductModel>>(
            stream: SearchService.allProductsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: _ink));
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No product data loaded.'));
              }

              final currentModel = snapshot.data!.values.where((p) => p.code == currentProductCode).firstOrNull;
              final currentCat = currentModel?.categoryCode;

              var allP = snapshot.data!.values
                  .where((p) => p.code != currentProductCode)
                  .toList();

              List<FirebaseProductModel> items = [];

              if (currentCat != null) {
                final sameCat = allP.where((p) => p.categoryCode == currentCat).toList();
                sameCat.shuffle();
                items.addAll(sameCat.take(10));
              }

              // If we don't have enough similar items, fill the rest with random items
              if (items.length < 10) {
                final remaining = allP.where((p) => !items.contains(p)).toList();
                remaining.shuffle();
                items.addAll(remaining.take(10 - items.length));
              }

              if (items.isEmpty) {
                return const Center(child: Text('No related products found.'));
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                clipBehavior: Clip.none,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    child: _SuggestionCard(fbProduct: items[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.fbProduct});
  final FirebaseProductModel fbProduct;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final appProd = Product(
            name: fbProduct.name,
            weight: fbProduct.weight,
            image: fbProduct.picUrl ?? '',
            price: fbProduct.price.toDouble(),
            oldPrice: fbProduct.originalPrice.toDouble(),
            discount: fbProduct.discount.toInt(),
            productCode: fbProduct.code,
            unit: fbProduct.unit,
            description: fbProduct.details,
            isOutOfStock: false,
          );

          // Push the new product details page, creating a drill-down experience
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: appProd,
                heroTag: 'suggest_${fbProduct.code}',
              ),
            ),
          );
        },
        child: Container(
          width: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Hero(
                  tag: 'suggest_${fbProduct.code}',
                  child: Container(
                    color: Colors.white, // ensures white background behind image
                    padding: const EdgeInsets.all(8),
                    child: fbProduct.picUrl != null && fbProduct.picUrl!.isNotEmpty
                        ? OptimizedNetworkImage(
                            imageUrl: fbProduct.picUrl!,
                            width: 120,
                            height: 100,
                            fit: BoxFit.contain,
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined, color: _priceMuted),
                          ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(
                    color: _surface, 
                    border: Border(top: BorderSide(color: _border, width: 0.5)),
                  ),
                  child: Center(
                    child: Text(
                      fbProduct.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        height: 1.25,
                      ),
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

// ─── Data class ───────────────────────────────────────────────────────────
class _VariantData {
  final String variantId;
  final String label;
  final String subtitle;
  final double price;
  final double oldPrice;
  final int quantity;
  final int discountPercent;
  const _VariantData({
    required this.variantId,
    required this.label,
    required this.subtitle,
    required this.price,
    required this.oldPrice,
    required this.quantity,
    this.discountPercent = 0,
  });
}
