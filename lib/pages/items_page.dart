import 'dart:async';
import '../layout/responsive_layout.dart';
import '../widgets/global_search_overlay.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:provider/provider.dart';

import '../cart_scope.dart';
import '../cart_controller.dart';
import '../debug/rebuild_tracker.dart';
import '../models/category_model.dart';
import '../models/firebase_product_model.dart';
import '../models/product.dart' as app_models;
import '../providers/category_provider.dart';
import '../location_service.dart';
import '../providers/delivery_location_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/order_provider.dart';
import '../providers/items_cache_provider.dart';
import '../services/search_service.dart';
import '../services/personalize_service.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import '../widgets/track_order_fab.dart';
import 'cart_page.dart';
import 'product_details_page.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/stock_provider.dart';
import '../models/stock_variant_model.dart';
import '../widgets/items/item_card_product.dart';
import '../widgets/items/item_card.dart';
import '../widgets/cart_edit_bottom_sheet.dart';
import '../widgets/items/add_button.dart';

// Categories fetched live from Firebase (root/category/{code}/name).
// Products fetched live from Firebase (root/products/{code}/).

// ─────────────────────────────────────────────────────────────────────────────
// Root page
// ─────────────────────────────────────────────────────────────────────────────

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, this.initialCategory, this.initialSearchQuery});

  /// Optional initial category label.
  final String? initialCategory;
  final String? initialSearchQuery;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage>
    with RebuildTracker<ItemsPage>, TickerProviderStateMixin {
  // ── Category / browse state ────────────────────────────────────────────────
  Future<List<CategoryModel>>? _categoriesFuture;
  List<CategoryModel> _categoryModels = const [];
  List<String> _categories = const [];
  String _selectedCategory = '';
  String _selectedCategoryCode = '';

  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 15;
  late final AnimationController _entranceController;
  late final PageController _pageController;
  bool? _isOver18;

  Future<void> _checkTobaccoAgeVerification() async {
    if (_selectedCategoryCode == 'CTC018' && _isOver18 == null) {
      final isAdult = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, anim1, anim2) {
          final theme = AppThemeScope.themeOf(context);
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: anim1,
              child: AlertDialog(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.primaryAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: theme.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Age Verification',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You must be 18 years or older to view or purchase tobacco products according to local laws.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.black54,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Colors.redAccent.shade100,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'Under 18',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'I am 18+',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
          );
        },
      );
      if (mounted) {
        setState(() {
          _isOver18 = isAdult ?? false;
        });
      }
    }
  }

  // ── Global search state ────────────────────────────────────────────────────
  String _searchQuery = '';
  Map<String, FirebaseProductModel> _allProducts = {};
  StreamSubscription<Map<String, FirebaseProductModel>>? _allProductsSub;
  SearchResultSet _searchResults = const SearchResultSet(
    categoryHits: [],
    productHits: [],
  );
  bool _allProductsLoaded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController.addListener(_onScroll);

    // If an initial query was passed, update state immediately
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!;
    }

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    void loadData() {
      if (!mounted) return;

      setState(() {
        _categoriesFuture = CategoryProvider.getCategoriesOnce();
      });

      _entranceController.forward();

      // Stream ALL products globally for fuzzy search
      _allProductsSub = SearchService.allProductsStream().listen((map) {
        if (!mounted) return;
        // Don't trigger expensive rebuilds while this page is sliding off screen
        // during a back-navigation.
        final route = ModalRoute.of(context);
        if (route == null) return;
        // Don't trigger expensive rebuilds while this page is transitioning or in background.
        if (route.animation?.isAnimating == true || !route.isCurrent) return;

        setState(() {
          _allProducts = map;
          _allProductsLoaded = true;
          if (_searchQuery.isNotEmpty) _runGlobalSearch(_searchQuery);
        });
      });
    }

    // If data is already cached, execute instantly if we are already settled,
    // otherwise wait for the route transition to finish to prevent navigation jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || route.isCurrent == false) {
        // Not a standard route navigation or already finished?
        loadData();
      } else {
        // Wait for the slide/fade transition to finish 100%
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route.animation?.removeStatusListener(listener);
            loadData();
          }
        }

        route.animation?.addStatusListener(listener);
        // Fallback for edge cases where status might not trigger as expected
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && _categoriesFuture == null) loadData();
        });
      }
    });
  }

  void _onScroll() {
    final route = ModalRoute.of(context);
    if (route == null ||
        route.animation?.isAnimating == true ||
        !route.isCurrent)
      return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (mounted) {
        setState(() {
          _currentLimit += 15;
        });
      }
    }
  }

  /// Called when a new category list arrives from Firebase.
  void _onCategoriesLoaded(List<CategoryModel> models) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final names = models.map((m) => m.name).toList();
    if (names.isEmpty) return;
    if (names.join(',') == _categories.join(',')) return;
    setState(() {
      _categoryModels = models;
      _categories = names;
      CategoryModel? selected;
      if (_selectedCategory.isNotEmpty &&
          _categories.contains(_selectedCategory)) {
        selected = models.firstWhere((m) => m.name == _selectedCategory);
      } else if (widget.initialCategory != null &&
          _categories.contains(widget.initialCategory)) {
        selected = models.firstWhere((m) => m.name == widget.initialCategory);
      } else {
        selected = models.first;
      }
      _selectedCategory = selected.name;
      _selectedCategoryCode = selected.code;

      final cache = context.read<ItemsCacheProvider>();
      cache.fetchCategoryProducts(_selectedCategoryCode);
      if (models.length > 1) {
        cache.preloadInitialCategories([models[0].code, models[1].code]);
      }

      final index = _categories.indexOf(_selectedCategory);
      if (index >= 0 && _pageController.hasClients) {
        _pageController.jumpToPage(index);
      }

      if (_selectedCategoryCode == 'CTC018') {
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkTobaccoAgeVerification,
        );
      } else {
        _isOver18 = null;
      }
    });
  }

  @override
  void dispose() {
    _allProductsSub?.cancel();
    _scrollController.dispose();
    _entranceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onCategoryIndexChanged(int index) {
    if (index < 0 || index >= _categories.length) return;
    final value = _categories[index];
    if (_selectedCategory == value) return;

    _entranceController.forward(from: 0);
    setState(() {
      _selectedCategory = value;
      final model = _categoryModels[index];
      _selectedCategoryCode = model.code;

      context.read<ItemsCacheProvider>().fetchCategoryProducts(
        _selectedCategoryCode,
      );

      // Clear search when switching categories
      if (_searchQuery.isNotEmpty) {
        _searchQuery = '';
        _searchResults = const SearchResultSet(
          categoryHits: [],
          productHits: [],
        );
      }
      if (_selectedCategoryCode == 'CTC018') {
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkTobaccoAgeVerification,
        );
      } else {
        _isOver18 = null;
      }
    });
  }


  void _onCategoryChanged(String value) {
    final index = _categories.indexOf(value);
    if (index >= 0) {
      _onCategoryIndexChanged(index);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onSearchQueryReceived(String query) {
    if (!mounted) return;
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _searchQuery = q;
      _currentLimit = 15;
    });
    _runGlobalSearch(q);
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchResults = const SearchResultSet(categoryHits: [], productHits: []);
    });
  }

  void _runGlobalSearch(String query) {
    if (!_allProductsLoaded || query.isEmpty) return;
    final results = SearchService.search(
      query: query,
      products: _allProducts,
      categories: _categoryModels,
    );

    // Sort product hits by stock status
    final sortedProductHits = List<ProductSearchResult>.from(
      results.productHits,
    );
    sortedProductHits.sort((a, b) {
      final aProd = a.product;
      final bProd = b.product;

      final aComingSoon = aProd.price == 0;
      final bComingSoon = bProd.price == 0;

      int getRank(bool comingSoon) {
        if (comingSoon) return 5;
        return 0;
      }

      final rankA = getRank(aComingSoon);
      final rankB = getRank(bComingSoon);

      if (rankA != rankB) return rankA.compareTo(rankB);
      // Secondary sort by fuzzy match score (descending)
      return b.matchScore.compareTo(a.matchScore);
    });

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    setState(
      () => _searchResults = results.copyWith(productHits: sortedProductHits),
    );
    _entranceController.forward(from: 0);
  }

  void _handleQuantityChanged(
    app_models.Product product,
    int newQty,
    int variantIndex,
  ) {
    if (_selectedCategoryCode == 'CTC018' && _isOver18 == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are under 18. Purchasing tobacco is a punishable offense.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    CartScope.read(
      context,
    ).setQuantity(product, newQty, variantIndex: variantIndex);
  }

  @override
  Widget buildTracked(BuildContext context) {
    final CartController cart = CartScope.read(context);
    final bool isSearching = _searchQuery.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppThemeScope.themeOf(context).gradientTop,
            const Color(0xFFF3F4F6),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _ItemsHeaderSliver(
                  activeQuery: _searchQuery,
                  onTapSearch: () async {
                    final q = await showGlobalSearch(context);
                    if (q != null && q.isNotEmpty) {
                      _onSearchQueryReceived(q);
                      if (mounted) {
                        final phone = context.read<UserProfileProvider>().phone;
                        PersonalizeService.logSearch(phone, q);
                      }
                    }
                  },
                  onClearSearch: _clearSearch,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Category chips: hidden while a global search is active ──
                if (!isSearching)
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<CategoryModel>>(
                      initialData: CategoryProvider.cachedCategories,
                      future: _categoriesFuture,
                      builder: (context, snapshot) {
                        if (_categoriesFuture != null && snapshot.hasData) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _onCategoriesLoaded(snapshot.data!);
                          });
                        }
                        if (_categories.isEmpty) {
                          return const _ChipsShimmer();
                        }
                        return SizedBox(
                          height: 42,
                          child: RepaintBoundary(
                            child: CategoryChipsWidget(
                              categories: _categories,
                              selected: _selectedCategory,
                              onChanged: _onCategoryChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 2)),

                const SliverToBoxAdapter(child: SizedBox(height: 6)),

                if (!isSearching &&
                    _selectedCategory.toLowerCase().contains('tobacco') &&
                    _isOver18 == false)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You are under 18. You cannot purchase tobacco products. It is a punishable offense.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                isSearching
                    ? _buildSearchResultsSliver(cart)
                    : _buildCategoryProductsSliver(cart),
              ],
            ),

            // ── Floating cart bar ──────────────────────────────────────────
            ListenableBuilder(
              listenable: cart,
              builder: (context, _) {
                if (cart.count == 0) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: RepaintBoundary(
                      child: FloatingCartBarWidget(
                        itemCount: cart.count,
                        total: cart.totalPrice,
                        onViewCart: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CartPage(),
                          ),
                        ),
                        onClearCart: () =>
                            CartEditBottomSheet.show(context, cart),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Active order FAB ───────────────────────────────────────────
            Consumer<OrderProvider>(
              builder: (context, orderProvider, _) {
                final activeOrders = orderProvider.activeOrders;
                if (activeOrders.isEmpty) return const SizedBox.shrink();
                final latestOrder = activeOrders.first;
                return DraggableTrackOrderFab(
                  orderId: latestOrder.orderId,
                  activeCount: activeOrders.length,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Global fuzzy-search sliver ─────────────────────────────────────────────
  Widget _buildSearchResultsSliver(CartController cart) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    final results = _searchResults;

    // While the all-products stream hasn't arrived yet show shimmer
    if (!_allProductsLoaded) {
      return const SliverToBoxAdapter(child: _ProductsShimmer());
    }

    // Empty-state
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: accent.withValues(alpha: 0.28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Items not available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try a different spelling or browse a category',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final catHits = results.categoryHits;
    final prodHits = results.productHits;
    // Section header + items counts
    final catCount = catHits.isNotEmpty ? catHits.length + 1 : 0;
    final prodCount = prodHits.isNotEmpty ? prodHits.length + 1 : 0;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // ── Category section ──────────────────────────────────────────
            if (catHits.isNotEmpty) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SRLabel(
                    'CATEGORIES (${catHits.length})',
                    Icons.grid_view_rounded,
                    accent,
                  ),
                );
              }
              if (index <= catHits.length) {
                final hit = catHits[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SRCategoryChip(
                    hit: hit,
                    accent: accent,
                    onTap: () {
                      _clearSearch();
                      _onCategoryChanged(hit.category.name);
                    },
                  ),
                );
              }
            }

            // ── Product section ───────────────────────────────────────────
            final prodBase = catCount;
            if (prodHits.isNotEmpty && index == prodBase) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: _SRLabel(
                  'PRODUCTS (${prodHits.length})',
                  Icons.shopping_bag_outlined,
                  accent,
                ),
              );
            }
            final prodIdx = index - prodBase - (prodHits.isNotEmpty ? 1 : 0);
            if (prodIdx >= 0 && prodIdx < prodHits.length) {
              final hit = prodHits[prodIdx];
              final fbProd = hit.product;
              final priceOverride = fbProd.price;
              final product = ItemCardProduct.fromFirebase(
                fbProd,
              ).copyWith(price: priceOverride);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SRProductRow(
                  hit: hit,
                  product: product,
                  accent: accent,
                  cart: cart,
                  onQuantityChanged: _handleQuantityChanged,
                ),
              );
            }

            return const SizedBox.shrink();
          },
          childCount: catCount + prodCount,
        ),
      ),
    );
  }

  Widget _buildUnderageBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '18+ strict requirement',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'You are under 18. Purchasing tobacco is a punishable offense. You may view these products but cannot purchase them.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category-scoped browse sliver (original behaviour) ────────────────────
  Widget _buildCategoryProductsSliver(CartController cart) {
    return Selector<ItemsCacheProvider, List<FirebaseProductModel>?>(
      selector: (context, provider) => provider.getCategoryProducts(_selectedCategoryCode),
      builder: (context, products, child) {
        Widget content;

        if (products == null) {
          // Null means not yet loaded. Show skeleton to avoid blank screens
          content = const SliverToBoxAdapter(child: _ProductsShimmer());
        } else if (products.isEmpty) {
          content = SliverToBoxAdapter(
            child: Padding(
              key: const ValueKey('empty_state'),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Center(
                child: Text(
                  'No products in this category yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Prefetch visible images — use exact URLs so CachedNetworkImage hits cache
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (int i = 0; i < products.length && i < 15; i++) {
              final url = products[i].picUrl;
              if (url != null && url.isNotEmpty) {
                precacheImage(
                  CachedNetworkImageProvider(
                    url,
                    maxWidth: 300,
                    maxHeight: 300,
                  ),
                  context,
                  onError: (e, st) {},
                );
              }
            }
          });

          final List<FirebaseProductModel> sortedList = List.from(products);
          sortedList.sort((a, b) {
            final aComingSoon = a.price == 0;
            final bComingSoon = b.price == 0;

            int getRank(bool comingSoon) {
              if (comingSoon) return 5;
              return 0;
            }

            final rankA = getRank(aComingSoon);
            final rankB = getRank(bComingSoon);

            if (rankA != rankB) return rankA.compareTo(rankB);
            return a.name.compareTo(b.name);
          });

          final paginatedList = sortedList.take(_currentLimit).toList();

          final grid = AppGridConfig.of(context);
          final sp = AppSpacing.of(context);

          final gridView = SliverPadding(
            key: PageStorageKey<String>('grid_${_selectedCategoryCode}'),
            padding: EdgeInsets.fromLTRB(
              sp.screenPadding,
              4,
              sp.screenPadding,
              84,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220.0,
                mainAxisSpacing: sp.gridSpacing,
                crossAxisSpacing: sp.gridSpacing,
                childAspectRatio: grid.childAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final fbProduct = paginatedList[index];
                  final priceOverride = fbProduct.price;
                  final product = ItemCardProduct.fromFirebase(
                    fbProduct,
                  ).copyWith(price: priceOverride);

                  Widget child = ListenableBuilder(
                    listenable: cart,
                    builder: (context, _) {
                      final cartCount = cart.entries
                          .where((e) => e.product.productCode == fbProduct.code)
                          .fold(0, (sum, e) => sum + e.quantity);
                      final bool blockTap =
                          _selectedCategoryCode == 'CTC018' && _isOver18 == false;
                      return ItemCard(
                        key: ValueKey(fbProduct.code),
                        product: product,
                        cartCount: cartCount,
                        onQuantityChanged: _handleQuantityChanged,
                        onTap: blockTap
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.block_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'You are under 18. Viewing tobacco product details is restricted.',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    },
                  );

                  return child;
                },
                childCount: paginatedList.length,
              ),
            ),
          );

          if (_selectedCategoryCode == 'CTC018' && _isOver18 == false) {
            content = SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: _buildUnderageBanner()),
                gridView,
              ],
            );
          } else {
            content = gridView;
          }
        }

        return content;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Section label row (e.g. "CATEGORIES (3)" or "PRODUCTS (12)")
class _SRLabel extends StatelessWidget {
  const _SRLabel(this.label, this.icon, this.accent);

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: accent.withValues(alpha: 0.2), height: 1),
        ),
      ],
    );
  }
}

/// A tappable category chip shown inside search results
class _SRCategoryChip extends StatelessWidget {
  const _SRCategoryChip({
    required this.hit,
    required this.accent,
    required this.onTap,
  });

  final CategorySearchResult hit;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = hit.matchScore; // 0–100 int
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.grid_view_rounded, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hit.category.name,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (pct < 100)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal product card shown inside search results
class _SRProductRow extends StatelessWidget {
  const _SRProductRow({
    required this.hit,
    required this.product,
    required this.accent,
    required this.cart,
    required this.onQuantityChanged,
  });

  final ProductSearchResult hit;
  final ItemCardProduct product;
  final Color accent;
  final CartController cart;
  final void Function(app_models.Product, int, int) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final pct = hit.matchScore; // 0–100 int
    final fbProduct = hit.product;

    return StreamBuilder<List<StockVariantModel>>(
      stream: StockProvider.stockStream(fbProduct.code),
      builder: (context, snapshot) {
        final variants = snapshot.data ?? [];
        final isOut =
            variants.isNotEmpty && variants.every((v) => v.quantity <= 0);
        final totalQty = variants.fold(0, (sum, v) => sum + v.quantity);

        return GestureDetector(
          onTap: () {
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
              isOutOfStock: isOut,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailsPage(
                  product: appProd,
                  heroTag: 'search_${fbProduct.code}',
                ),
              ),
            );
          },
          child: RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Product image
                  Hero(
                    tag: 'search_${fbProduct.code}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            color: Colors.white,
                            child:
                                (fbProduct.picUrl != null &&
                                    fbProduct.picUrl!.isNotEmpty)
                                ? OptimizedNetworkImage(
                                    imageUrl: fbProduct.picUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Color(0xFF9CA3AF),
                                    size: 32,
                                  ),
                          ),

                          if (isOut)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.05),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'OUT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name + price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pct < 100)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pct% match',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          fbProduct.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final price = (variants.isNotEmpty
                                    ? variants.first.offerPrice
                                    : fbProduct.price);
                                if (price == 0) {
                                  return Container(
                                    width: 48,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }
                                return Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                );
                              },
                            ),
                            if ((variants.isNotEmpty
                                    ? variants.first.label(fbProduct.unit)
                                    : fbProduct.weight)
                                .isNotEmpty)
                              Text(
                                (variants.isNotEmpty
                                    ? variants.first.label(fbProduct.unit)
                                    : fbProduct.weight),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add button
                  ListenableBuilder(
                    listenable: cart,
                    builder: (context, _) {
                      final appProduct = app_models.Product(
                        name: fbProduct.name,
                        weight: fbProduct.weight,
                        image: fbProduct.picUrl ?? '',
                        price: fbProduct.price.toDouble(),
                        oldPrice: fbProduct.originalPrice.toDouble(),
                        discount: fbProduct.discount.toInt(),
                        productCode: fbProduct.code,
                        unit: fbProduct.unit,
                        description: fbProduct.details,
                        isOutOfStock: isOut,
                      );
                      final cartCount = cart.entries
                          .where((e) => e.product.productCode == fbProduct.code)
                          .fold(0, (sum, e) => sum + e.quantity);

                      // Disable adding if totally out of stock, or if we hit the limit
                      final bool isDisabled =
                          isOut ||
                          (variants.isNotEmpty && (totalQty - cartCount) <= 0);

                      final int selectedVariantIndex = variants.isNotEmpty
                          ? (variants.indexWhere((v) => v.quantity > 0) >= 0
                                ? variants.indexWhere((v) => v.quantity > 0)
                                : 0)
                          : 0;

                      return AddButton(
                        externalQuantity: cartCount,
                        isDisabled: isDisabled,
                        onQuantityChanged: (qty) => onQuantityChanged(
                          appProduct,
                          qty,
                          selectedVariantIndex,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (location + cart icon row)
// ─────────────────────────────────────────────────────────────────────────────

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  static final _titleStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
  );

  static TextStyle _subtitleStyle(BuildContext context) => TextStyle(
    fontFamily: "PlusJakartaSans",
    color: AppThemeScope.themeOf(context).primaryAccent.withValues(alpha: 0.9),
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  Future<void> _handleLocationTap(BuildContext context) async {
    final result = await LocationService.getCurrentLocation(context);
    if (!context.mounted || result == null) return;
    context.read<DeliveryLocationProvider>().update(result.formattedAddress);
    await context.read<UserProfileProvider>().updateAddressLegacy(
      result.formattedAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryLocationProvider>(
      builder: (context, locationProvider, _) {
        return Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _handleLocationTap(context),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            locationProvider.city,
                            style: _titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationProvider.address,
                      style: _subtitleStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            CartIconWithBadge(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const CartPage())),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header sliver helper
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsHeaderSliver extends StatelessWidget {
  const _ItemsHeaderSliver({
    required this.activeQuery,
    required this.onTapSearch,
    required this.onClearSearch,
  });

  final String activeQuery;
  final VoidCallback onTapSearch;
  final VoidCallback onClearSearch;

  static const double _expandedHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final Color headerColor = AppThemeScope.themeOf(context).gradientTop;

    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight + topPadding,
      automaticallyImplyLeading: false,
      backgroundColor: headerColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double maxHeight = _expandedHeight + topPadding;
          final double minHeight = kToolbarHeight + topPadding;
          final double t =
              ((constraints.biggest.height - minHeight) /
                      (maxHeight - minHeight))
                  .clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 8 * t,
                left: 20,
                right: 20,
                bottom: 8,
              ),
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        heightFactor: t > 0 ? t : 0,
                        child: const HeaderWidget(),
                      ),
                    ),
                    SizedBox(height: 6 * t),
                    _ItemsSearchPill(
                      activeQuery: activeQuery,
                      onTapSearch: onTapSearch,
                      onClearSearch: onClearSearch,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart icon with badge
// ─────────────────────────────────────────────────────────────────────────────

class CartIconWithBadge extends StatelessWidget {
  const CartIconWithBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  static final _badgeStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    final CartController cart = CartScope.of(context);
    final accent = AppThemeScope.themeOf(context).primaryAccent;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: ListenableBuilder(
              listenable: cart,
              builder: (context, _) {
                final int count = cart.count;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text('$count', style: _badgeStyle),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified search pill — matches HomePage design
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsSearchPill extends StatefulWidget {
  const _ItemsSearchPill({
    required this.activeQuery,
    required this.onTapSearch,
    required this.onClearSearch,
  });

  final String activeQuery;
  final VoidCallback onTapSearch;
  final VoidCallback onClearSearch;

  @override
  State<_ItemsSearchPill> createState() => _ItemsSearchPillState();
}

class _ItemsSearchPillState extends State<_ItemsSearchPill>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  // Cycling hint strings (matches HomePage)
  static const _hints = [
    'Search "Milk"',
    'Search "Rice"',
    'Search "Soap"',
    'Search "Fruits"',
    'Search "Snacks"',
  ];
  int _hintIndex = 0;
  Timer? _hintTimer;

  // Animation for hint text swap
  late final AnimationController _hintCtrl;
  late final Animation<double> _hintFade;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1.0;
    _hintFade = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut);
    _startHintCycle();
  }

  void _startHintCycle() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (widget.activeQuery.isNotEmpty) return; // Pause cycle if query active
      _hintCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _hintIndex = (_hintIndex + 1) % _hints.length;
        });
        _hintCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintCtrl.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    final hasActiveQuery = widget.activeQuery.isNotEmpty;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onTapSearch,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: widget.onTapSearch,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                child: Container(
                  color: Colors.transparent, // Catch all taps
                  alignment: Alignment.centerLeft,
                  child: hasActiveQuery
                      ? Text(
                          widget.activeQuery,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : FadeTransition(
                          opacity: _hintFade,
                          child: Text(
                            _hints[_hintIndex],
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
            ),
            if (hasActiveQuery)
              GestureDetector(
                onTap: widget.onClearSearch,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 14, color: accent),
                ),
              )
            else
              const SizedBox(width: 28), // Spacer instead of mic
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chips
// ─────────────────────────────────────────────────────────────────────────────

class CategoryChipsWidget extends StatefulWidget {
  const CategoryChipsWidget({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  State<CategoryChipsWidget> createState() => _CategoryChipsWidgetState();
}

class _CategoryChipsWidgetState extends State<CategoryChipsWidget> {
  final ScrollController _scrollController = ScrollController();

  static final _selectedStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );
  static final _unselectedStyle = TextStyle(
    fontFamily: "PlusJakartaSans",
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: const Color.fromARGB(251, 0, 0, 0),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CategoryChipsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelected(animate: true);
      });
    }
  }

  void _scrollToSelected({bool animate = true}) {
    final index = widget.categories.indexOf(widget.selected);
    if (index == -1 || !_scrollController.hasClients) return;
    double offset = 0.0;
    for (int i = 0; i < index; i++) {
      offset += 32.0 + (widget.categories[i].length * 8.0) + 12.0;
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = 32.0 + (widget.categories[index].length * 8.0);
    final targetOffset = offset - (screenWidth / 2) + (itemWidth / 2) + 20.0;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) {
        final label = widget.categories[index];
        final isSelected = label == widget.selected;
        return GestureDetector(
          onTap: () => widget.onChanged(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? accent : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? accent : const Color(0xFFE5E7EB),
                width: isSelected ? 1 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: isSelected ? _selectedStyle : _unselectedStyle,
              ),
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemCount: widget.categories.length,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chips shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _ChipsShimmer extends StatefulWidget {
  const _ChipsShimmer();

  @override
  State<_ChipsShimmer> createState() => _ChipsShimmerState();
}

class _ChipsShimmerState extends State<_ChipsShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Container(
            width: 80 + (index % 2) * 20.0,
            height: 36,
            decoration: BoxDecoration(
              color: Color.fromRGBO(203, 213, 225, _anim.value),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Products shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _ProductsShimmer extends StatefulWidget {
  const _ProductsShimmer();

  @override
  State<_ProductsShimmer> createState() => _ProductsShimmerState();
}

class _ProductsShimmerState extends State<_ProductsShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.25,
      end: 0.65,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: 4,
      itemBuilder: (context, _) => AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            color: Color.fromRGBO(203, 213, 225, _anim.value),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating cart summary bar
// ─────────────────────────────────────────────────────────────────────────────

class FloatingCartBarWidget extends StatelessWidget {
  const FloatingCartBarWidget({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onViewCart,
    required this.onClearCart,
  });

  final int itemCount;
  final double total;
  final VoidCallback onViewCart;
  final VoidCallback onClearCart;

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
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onViewCart,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('TOTAL', style: _totalLabelStyle),
                          const SizedBox(height: 2),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: _totalStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
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
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ],
                      ),
                    ),
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
