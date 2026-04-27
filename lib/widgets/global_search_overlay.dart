import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category_model.dart';
import '../models/firebase_product_model.dart';
import '../models/product.dart' as app_models;
import '../models/stock_variant_model.dart';
import '../providers/category_provider.dart';
import '../providers/recent_search_provider.dart';
import '../providers/stock_provider.dart';
import '../services/search_service.dart';
import '../theme/app_colors.dart';
import '../pages/product_details_page.dart';
import '../widgets/optimized_network_image.dart';
import '../pages/items_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry-point: show the search overlay from any page
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> showGlobalSearch(BuildContext context) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim, secondAnim) => const _GlobalSearchPage(),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen search page
// ─────────────────────────────────────────────────────────────────────────────

class _GlobalSearchPage extends StatefulWidget {
  const _GlobalSearchPage();

  @override
  State<_GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<_GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  // Debounce timer
  Timer? _debounce;

  // Data from Firebase
  Map<String, FirebaseProductModel> _allProducts = {};
  List<CategoryModel> _allCategories = [];
  StreamSubscription<Map<String, FirebaseProductModel>>? _productSub;

  // Current results
  SearchResultSet _results =
      const SearchResultSet(categoryHits: [], productHits: []);
  String _query = '';
  bool _loading = true;

  late final AnimationController _listAnimCtrl;
  double _lastKeyboardHeight = 0;

  // final VoiceSearchService _voiceService = VoiceSearchService(); // REMOVED
  // bool _isListening = false; // REMOVED

  @override
  void initState() {
    super.initState();
    _listAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _loadData();
    });
  }

  Future<void> _loadData() async {
    // Load categories from cache (instant)
    final cats = await CategoryProvider.getCategoriesOnce();
    if (!mounted) return;
    setState(() {
      _allCategories = cats;
    });

    // Stream all products
    _productSub = SearchService.allProductsStream().listen((map) {
      if (!mounted) return;
      setState(() {
        _allProducts = map;
        _loading = false;
        if (_query.isNotEmpty) _runSearch(_query);
      });
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _runSearch(value.trim());
    });
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = const SearchResultSet(categoryHits: [], productHits: []);
      });
      return;
    }
    final results = SearchService.search(
      query: query,
      products: _allProducts,
      categories: _allCategories,
    );
    setState(() => _results = results);
    _listAnimCtrl.forward(from: 0);
  }

  /* 
  void _startVoiceSearch() async {
     ... removed ...
  }
  */

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (_lastKeyboardHeight > 100 && keyboardHeight < 10) {
      FocusScope.of(context).unfocus();
    }
    _lastKeyboardHeight = keyboardHeight;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    _focus.dispose();
    _productSub?.cancel();
    _listAnimCtrl.dispose();
    super.dispose();
  }

  void _navigateToCategoryResult(CategorySearchResult result) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemsPage(initialCategory: result.category.name),
      ),
    );
  }

  void _navigateToCategory(CategoryModel cat) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemsPage(initialCategory: cat.name),
      ),
    );
  }

  void _onProductTap(ProductSearchResult hit) {
    context.read<RecentSearchProvider>().addItem(hit.product);
    final fbProduct = hit.product;
    final appProd = app_models.Product(
      name: fbProduct.name,
      weight: fbProduct.weight,
      image: fbProduct.picUrl ?? '',
      price: fbProduct.price,
      oldPrice: fbProduct.originalPrice,
      discount: fbProduct.discount,
      productCode: fbProduct.code,
      unit: fbProduct.unit,
      description: fbProduct.details,
    );

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: appProd)),
    );
  }

  void _onRecentItemTap(FirebaseProductModel product) {
    context.read<RecentSearchProvider>().addItem(product);
    final appProd = app_models.Product(
      name: product.name,
      weight: product.weight,
      image: product.picUrl ?? '',
      price: product.price,
      oldPrice: product.originalPrice,
      discount: product.discount,
      productCode: product.code,
      unit: product.unit,
      description: product.details,
    );

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailsPage(product: appProd)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.themeOf(context);
    final accent = theme.primaryAccent;
    final headerColor = theme.gradientTop;
    final topPad = MediaQuery.of(context).padding.top;
    final hasQuery = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
          // ── Header with search bar ──────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: topPad + 12,
              left: 16,
              right: 16,
              bottom: 14,
            ),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Search field
                Expanded(
                  child: _SearchInputField(
                    controller: _textCtrl,
                    focusNode: _focus,
                    onChanged: _onSearchChanged,
                    accent: accent,
                    onClear: () {
                      _textCtrl.clear();
                      _onSearchChanged('');
                    },
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        Navigator.of(context).pop(val.trim());
                      }
                    },
                    // onVoiceTap: _startVoiceSearch, // REMOVED
                    // isListening: _isListening, // REMOVED
                  ),
                ),
              ],
            ),
          ),

          // ── Results ─────────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: !hasQuery
                  ? _SearchSuggestionsView(
                      categories: _allCategories,
                      accent: accent,
                      onCategoryTap: _navigateToCategory,
                      onRecentItemTap: _onRecentItemTap,
                    )
                  : _loading
                  ? _LoadingView(accent: accent)
                  : _results.isEmpty
                  ? _EmptyResultsView(query: _query, accent: accent)
                  : _ResultsListView(
                      key: ValueKey(_query),
                      results: _results,
                      query: _query,
                      accent: accent,
                      onCategoryTap: _navigateToCategoryResult,
                      onProductTap: _onProductTap,
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search input field
// ─────────────────────────────────────────────────────────────────────────────

class _SearchInputField extends StatelessWidget {
  const _SearchInputField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.accent,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Color accent;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: 'Search products & categories…',
                hintStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
                isCollapsed: true,
                border: InputBorder.none,
              ),
              cursorColor: accent,
            ),
          ),
          // Clear or Voice button — animated
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: controller.text.isNotEmpty
                ? GestureDetector(
                    key: const ValueKey('clear'),
                    onTap: onClear,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  )
                : const SizedBox(width: 32), // Spacer instead of mic
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestions view (shown when query is empty)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSuggestionsView extends StatelessWidget {
  const _SearchSuggestionsView({
    required this.categories,
    required this.accent,
    required this.onCategoryTap,
    required this.onRecentItemTap,
  });

  final List<CategoryModel> categories;
  final Color accent;
  final ValueChanged<CategoryModel> onCategoryTap;
  final ValueChanged<FirebaseProductModel> onRecentItemTap;

  @override
  Widget build(BuildContext context) {
    final recentProvider = context.watch<RecentSearchProvider>();
    final recentItems = recentProvider.recentItems;
    final limitedCategories = categories.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
      children: [
        if (recentItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _SectionLabel('Last searched / viewed'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: recentItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = recentItems[index];
                return GestureDetector(
                  onTap: () => onRecentItemTap(item),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: OptimizedNetworkImage(
                            imageUrl: item.picUrl ?? '',
                            width: 70,
                            height: 70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionLabel('Browse Categories'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: limitedCategories
                .map(
                  (cat) => GestureDetector(
                    onTap: () => onCategoryTap(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results list view
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsListView extends StatelessWidget {
  const _ResultsListView({
    super.key,
    required this.results,
    required this.query,
    required this.accent,
    required this.onCategoryTap,
    required this.onProductTap,
  });

  final SearchResultSet results;
  final String query;
  final Color accent;
  final ValueChanged<CategorySearchResult> onCategoryTap;
  final ValueChanged<ProductSearchResult> onProductTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // ── Category hits ──────────────────────────────────────────────
        if (results.categoryHits.isNotEmpty) ...[
          _SectionLabel(
            'Categories (${results.categoryHits.length})',
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: results.categoryHits
                .map(
                  (hit) => _CategoryResultChip(
                    hit: hit,
                    query: query,
                    accent: accent,
                    onTap: () => onCategoryTap(hit),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Product hits ───────────────────────────────────────────────
        if (results.productHits.isNotEmpty) ...[
          _SectionLabel(
            'Products (${results.productHits.length})',
            icon: Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: 10),
          ...results.productHits.asMap().entries.map(
            (entry) => _ProductResultRow(
              hit: entry.value,
              query: query,
              accent: accent,
              delay: entry.key * 30,
              onTap: () => onProductTap(entry.value),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Category chip result ───────────────────────────────────────────────────

class _CategoryResultChip extends StatefulWidget {
  const _CategoryResultChip({
    required this.hit,
    required this.query,
    required this.accent,
    required this.onTap,
  });

  final CategorySearchResult hit;
  final String query;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_CategoryResultChip> createState() => _CategoryResultChipState();
}

class _CategoryResultChipState extends State<_CategoryResultChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isExact = widget.hit.matchScore == 100;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isExact
                ? widget.accent
                : widget.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: isExact ? Colors.white : widget.accent,
              ),
              const SizedBox(width: 6),
              _HighlightText(
                text: widget.hit.category.name,
                query: widget.query,
                baseStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isExact ? Colors.white : const Color(0xFF374151),
                ),
                highlightColor: isExact ? Colors.white : widget.accent,
              ),
              if (!isExact) ...[
                const SizedBox(width: 6),
                _MatchBadge(score: widget.hit.matchScore, accent: widget.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Product row result ─────────────────────────────────────────────────────

class _ProductResultRow extends StatefulWidget {
  const _ProductResultRow({
    required this.hit,
    required this.query,
    required this.accent,
    required this.delay,
    required this.onTap,
  });

  final ProductSearchResult hit;
  final String query;
  final Color accent;
  final int delay;
  final VoidCallback onTap;

  @override
  State<_ProductResultRow> createState() => _ProductResultRowState();
}

class _ProductResultRowState extends State<_ProductResultRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.hit.product;
    final isExact = widget.hit.matchScore == 100;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.picUrl != null && product.picUrl!.isNotEmpty
                        ? OptimizedNetworkImage(
                            imageUrl: product.picUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            borderRadius: 12,
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF9CA3AF),
                              size: 26,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightText(
                          text: product.name,
                          query: widget.query,
                          baseStyle: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          highlightColor: widget.accent,
                        ),
                        const SizedBox(height: 3),
                        StreamBuilder<List<StockVariantModel>>(
                          stream: StockProvider.stockStream(product.code),
                          builder: (context, snapshot) {
                            final variants = snapshot.data ?? [];
                            String displayUnit = '${product.weight} ${product.unit}'.trim();

                            if (variants.isNotEmpty) {
                              displayUnit = variants.first.label(product.unit);
                            }

                            return Row(
                              children: [
                                Text(
                                  widget.hit.categoryName,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: widget.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD1D5DB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  displayUnit,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Price + match badge
                  StreamBuilder<List<StockVariantModel>>(
                    stream: StockProvider.stockStream(product.code),
                    builder: (context, snapshot) {
                      final variants = snapshot.data ?? [];
                      double price = product.price;
                      double originalPrice = product.originalPrice;

                      if (variants.isNotEmpty) {
                        price = variants.first.offerPrice;
                        originalPrice = variants.first.mrp;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: widget.accent,
                            ),
                          ),
                          if (originalPrice > price) ...[
                            const SizedBox(height: 2),
                            Text(
                              '₹${originalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          if (!isExact) ...[
                            const SizedBox(height: 4),
                            _MatchBadge(
                                score: widget.hit.matchScore, accent: widget.accent),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade300,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
        ],
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score, required this.accent});
  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$score% match',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Highlights the part of [text] that matches the [query].
class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightColor,
  });

  final String text;
  final String query;
  final TextStyle baseStyle;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle);

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final matchIndex = lower.indexOf(qLower);

    if (matchIndex < 0) {
      // No direct match, no highlight needed
      return Text(text, style: baseStyle);
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + qLower.length),
            style: baseStyle.copyWith(
              color: highlightColor,
              backgroundColor: highlightColor.withValues(alpha: 0.12),
            ),
          ),
          TextSpan(text: text.substring(matchIndex + qLower.length)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: accent,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyResultsView extends StatelessWidget {
  const _EmptyResultsView({required this.query, required this.accent});
  final String query;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 38,
                color: accent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different spelling or browse categories below.',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
