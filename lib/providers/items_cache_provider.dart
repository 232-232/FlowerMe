import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import '../models/firebase_product_model.dart';
import '../debug/dc_log.dart';
import '../debug/perf_logger.dart';

class ItemsCacheProvider extends ChangeNotifier {
  final Map<String, List<FirebaseProductModel>> _cache = {};
  final Map<String, bool> _isLoading = {};

  /// Silently warms the browser/OS image cache for the first [limit] products.
  void _precacheProductImages(List<FirebaseProductModel> products, {int limit = 12}) {
    final element = WidgetsBinding.instance.rootElement;
    if (element == null) return;
    final count = products.length < limit ? products.length : limit;
    for (int i = 0; i < count; i++) {
      final url = products[i].picUrl;
      if (url == null || url.isEmpty) continue;
      // Use exact URL — must match what OptimizedNetworkImage builds
      precacheImage(
        CachedNetworkImageProvider(url, maxWidth: 300, maxHeight: 300),
        element,
        onError: (_, __) {},
      );
    }
 }

  /// Retrieves the cached products for a given category.
  List<FirebaseProductModel>? getCategoryProducts(String categoryCode) {
    return _cache[categoryCode];
  }

  /// Returns true if the given category is currently being loaded.
  bool isLoading(String categoryCode) {
    return _isLoading[categoryCode] ?? false;
  }

  /// Fetches products for a category only if not already cached and not currently loading.
  Future<void> fetchCategoryProducts(String categoryCode) async {
    if (categoryCode.isEmpty) return;
    if (_cache.containsKey(categoryCode)) return;
    if (_isLoading[categoryCode] == true) return;

    _isLoading[categoryCode] = true;
    notifyListeners();

    try {
      Perf.start('Firebase', 'ItemsCache fetch: $categoryCode');
      dcLog('ItemsCache', '🔌 Fetching products for category: $categoryCode');

      final snapshot = await FirebaseDatabase.instance
          .ref('root/products')
          .orderByChild('categoryCode')
          .equalTo(categoryCode)
          .once();

      if (!snapshot.snapshot.exists || snapshot.snapshot.value == null) {
        _cache[categoryCode] = [];
      } else {
        final raw = snapshot.snapshot.value as Map<Object?, Object?>;
        final products = <FirebaseProductModel>[];

        for (final entry in raw.entries) {
          final code = entry.key?.toString() ?? '';
          final data = entry.value;

          if (data is! Map<Object?, Object?>) continue;

          products.add(FirebaseProductModel.fromSnapshot(code, data));
        }
        _cache[categoryCode] = products;
      }

      // Warm image cache for the freshly fetched products
      final cached = _cache[categoryCode];
      if (cached != null && cached.isNotEmpty) {
        _precacheProductImages(cached);
      }

      dcLog(
        'ItemsCache',
        '📋 Cached ${_cache[categoryCode]?.length} products for "$categoryCode"',
      );
      Perf.end('Firebase', 'ItemsCache fetch: $categoryCode');
    } catch (e) {
      dcLog('ItemsCache', '❌ Error fetching products for $categoryCode: $e');
      _cache[categoryCode] = []; // Avoid infinite loading state on error
    } finally {
      _isLoading[categoryCode] = false;
      notifyListeners();
    }
  }

  /// Preloads the given categories in the background.
  Future<void> preloadInitialCategories(List<String> categoryCodes) async {
    for (final code in categoryCodes) {
      // Background fetch without awaiting sequentially to allow parallel loading
      fetchCategoryProducts(code);
    }
  }
}
