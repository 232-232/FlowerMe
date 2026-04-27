import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';

import '../models/category_model.dart';
import '../models/firebase_product_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Search result types
// ─────────────────────────────────────────────────────────────────────────────

class ProductSearchResult {
  const ProductSearchResult({
    required this.product,
    required this.categoryName,
    required this.matchScore, // 0–100
  });

  final FirebaseProductModel product;
  final String categoryName;
  final int matchScore;
}

class CategorySearchResult {
  const CategorySearchResult({
    required this.category,
    required this.matchScore,
  });

  final CategoryModel category;
  final int matchScore;
}

class SearchResultSet {
  const SearchResultSet({
    required this.categoryHits,
    required this.productHits,
  });

  final List<CategorySearchResult> categoryHits;
  final List<ProductSearchResult> productHits;

  bool get isEmpty => categoryHits.isEmpty && productHits.isEmpty;

  SearchResultSet copyWith({
    List<CategorySearchResult>? categoryHits,
    List<ProductSearchResult>? productHits,
  }) {
    return SearchResultSet(
      categoryHits: categoryHits ?? this.categoryHits,
      productHits: productHits ?? this.productHits,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchService
// ─────────────────────────────────────────────────────────────────────────────

class SearchService {
  SearchService._();

  // Cache all products in memory once fetched
  static Map<String, FirebaseProductModel>? _allProductsCache;
  static StreamSubscription? _productsSub;
  static final StreamController<Map<String, FirebaseProductModel>> _allProductsController =
      StreamController<Map<String, FirebaseProductModel>>.broadcast();

  static bool get hasCache => _allProductsCache != null && _allProductsCache!.isNotEmpty;

  /// Read a product synchronously from the cache if available.
  static FirebaseProductModel? getProductSync(String code) {
    return _allProductsCache?[code];
  }

  /// Start a live stream of all products (call once, usually when search opens).
  /// Subsequent calls reuse the same subscription.
  static Stream<Map<String, FirebaseProductModel>> allProductsStream() {
    // If not already listening to Firebase, start now
    if (_productsSub == null) {
      _productsSub = FirebaseDatabase.instance
          .ref('root/products')
          .onValue
          .listen((event) {
        final map = <String, FirebaseProductModel>{};
        if (event.snapshot.exists && event.snapshot.value != null) {
          final raw = event.snapshot.value as Map<Object?, Object?>;
          for (final entry in raw.entries) {
            final code = entry.key?.toString() ?? '';
            final data = entry.value;
            if (data is Map<Object?, Object?>) {
              map[code] = FirebaseProductModel.fromSnapshot(code, data);
            }
          }
        }
        _allProductsCache = map;
        if (!_allProductsController.isClosed) {
          _allProductsController.add(map);
        }
      });
    }

    // Return the shared broadcast stream
    // We wrap it in a custom stream to ensure new listeners get the current cache immediately
    final controller = StreamController<Map<String, FirebaseProductModel>>();
    if (_allProductsCache != null) {
      controller.add(_allProductsCache!);
    }

    final subscription = _allProductsController.stream.listen(
      (data) => controller.add(data),
      onError: (e) => controller.addError(e),
      onDone: () => controller.close(),
    );

    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Dispose the shared product subscription (call when app closes, optional).
  static void dispose() {
    _productsSub?.cancel();
    _productsSub = null;
    _allProductsCache = null;
  }

  // ── Fuzzy match ────────────────────────────────────────────────────────────

  /// Returns a score 0–100 indicating how well [query] matches [target].
  /// 100 = exact (case-insensitive contains), 0 = no relation.
  static int fuzzyScore(String query, String target) {
    if (query.isEmpty) return 0;
    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();

    // Exact contains → 100
    if (t.contains(q)) return 100;

    // Starts with → 95
    if (t.startsWith(q)) return 95;

    // Every word in query is contained in target → 90
    final qWords = q.split(RegExp(r'\s+'));
    if (qWords.every((w) => t.contains(w))) return 90;

    // Prefix of any word in target starts with query word → 85
    // This supports autocomplete-style matching for middle words.
    final tWords = t.split(RegExp(r'\s+'));
    if (qWords.any((qw) => tWords.any((tw) => tw.startsWith(qw)))) {
      return 85;
    }

    // Character n-gram similarity
    final ngramScore = _ngramSimilarity(q, t, n: 2);
    if (ngramScore >= 0.88) return (ngramScore * 100).round();

    // Jaro-Winkler style for handling minor typos
    final jaro = _jaroSimilarity(q, t);
    if (jaro >= 0.92) return (jaro * 100).round();

    return 0;
  }

  static double _ngramSimilarity(String a, String b, {int n = 2}) {
    Set<String> ngrams(String s) {
      final result = <String>{};
      for (var i = 0; i <= s.length - n; i++) {
        result.add(s.substring(i, i + n));
      }
      return result;
    }

    if (a.length < n || b.length < n) {
      // Fallback: query matches prefix of target → 0.80
      return b.startsWith(a) ? 0.80 : 0.0;
    }

    final aGrams = ngrams(a);
    final bGrams = ngrams(b);
    if (aGrams.isEmpty && bGrams.isEmpty) return 1.0;
    if (aGrams.isEmpty || bGrams.isEmpty) return 0.0;

    final intersection = aGrams.intersection(bGrams).length;
    return (2.0 * intersection) / (aGrams.length + bGrams.length);
  }

  static double _jaroSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0 || len2 == 0) return 0.0;

    final matchDistance = (math.max(len1, len2) / 2).floor() - 1;
    if (matchDistance < 0) return 0.0;

    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);
    int matches = 0;
    int transpositions = 0;

    for (var i = 0; i < len1; i++) {
      final start = math.max(0, i - matchDistance);
      final end = math.min(i + matchDistance + 1, len2);
      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    return (matches / len1 +
            matches / len2 +
            (matches - transpositions / 2) / matches) /
        3.0;
  }

  // ── Main search method ─────────────────────────────────────────────────────

  /// Perform fuzzy search across [products] and [categories].
  /// Only results with score ≥ [minScore] (default 80) are returned.
  static SearchResultSet search({
    required String query,
    required Map<String, FirebaseProductModel> products,
    required List<CategoryModel> categories,
    int minScore = 80,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchResultSet(categoryHits: [], productHits: []);
    }

    // Build category name → model lookup
    final catMap = {for (final c in categories) c.code: c.name};

    // Category hits
    final catHits = <CategorySearchResult>[];
    for (final cat in categories) {
      final score = fuzzyScore(q, cat.name);
      if (score >= minScore) {
        catHits.add(CategorySearchResult(category: cat, matchScore: score));
      }
    }
    catHits.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Product hits
    final prodHits = <ProductSearchResult>[];
    for (final product in products.values) {
      final nameScore = fuzzyScore(q, product.name);
      // Also check details / labelName for bonus matching
      int detailsScore = 0;
      if (product.details != null) {
        detailsScore = fuzzyScore(q, product.details!) ~/ 2; // halved weight
      }
      final score = math.max(nameScore, detailsScore);
      if (score >= minScore) {
        final catName = catMap[product.categoryCode] ?? product.categoryCode;
        prodHits.add(ProductSearchResult(
          product: product,
          categoryName: catName,
          matchScore: score,
        ));
      }
    }
    // Sort: exact first, then by score desc, then by name alphabetically
    prodHits.sort((a, b) {
      final sc = b.matchScore.compareTo(a.matchScore);
      if (sc != 0) return sc;
      return a.product.name.compareTo(b.product.name);
    });

    return SearchResultSet(categoryHits: catHits, productHits: prodHits);
  }
}
