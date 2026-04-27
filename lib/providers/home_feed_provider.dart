import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/firebase_product_model.dart';
import '../models/stock_variant_model.dart';
import '../models/feed_product_model.dart';
import '../debug/dc_log.dart';
import '../debug/perf_logger.dart';

class HomeFeedProvider extends ChangeNotifier {
  HomeFeedProvider();

  List<FeedProductModel> _trendingProducts = [];
  List<FeedProductModel> get trendingProducts => _trendingProducts;

  List<FeedProductModel> _bestSellers = [];
  List<FeedProductModel> get bestSellers => _bestSellers;

  List<FeedProductModel> _suggestionBoxItems = [];
  List<FeedProductModel> get suggestionBoxItems => _suggestionBoxItems;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription? _stockSub;
  StreamSubscription? _productsSub;

  StreamSubscription? _sgBoxSub;

  Map<String, Map<String, StockVariantModel>> _stockMap = {};
  Map<String, FirebaseProductModel> _productsMap = {};
  Map<String, Map<String, dynamic>> _sgBoxMap = {};

  bool _hasFetched = false;
  Timer? _debounceTimer;

  void fetchFeed() {
    if (_hasFetched) return;
    _hasFetched = true;

    if (Firebase.apps.isEmpty) {
      dcLog('HomeFeed', '⚠️ Firebase not initialized. Skipping feed fetch.');
      _isLoading = false;
      return;
    }

    dcLog('HomeFeed', '🔌 Initializing home feed streams (stock & products)...');
    Perf.start('Firebase', 'SuggestionBox data');
    
    _stockSub = FirebaseDatabase.instance.ref('root/stock').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _stockMap = {};
      } else {
        final raw = _safeMap(event.snapshot.value);
        final newStockMap = <String, Map<String, StockVariantModel>>{};
        
        for (final entry in raw.entries) {
          final productCode = entry.key;
          final variantsRaw = _safeMap(entry.value);
          
          if (variantsRaw.isEmpty) continue;
          
          final variantsMap = <String, StockVariantModel>{};
          for (final varEntry in variantsRaw.entries) {
            final variantId = varEntry.key;
            final varData = varEntry.value;
            if (varData is Map) {
              variantsMap[variantId] = StockVariantModel.fromSnapshot(variantId, varData);
            }
          }
          newStockMap[productCode] = variantsMap;
        }
        _stockMap = newStockMap;
      }
      _combineData();
    });

    _productsSub = FirebaseDatabase.instance.ref('root/products').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _productsMap = {};
      } else {
        final raw = _safeMap(event.snapshot.value);
        final newProductsMap = <String, FirebaseProductModel>{};
        
        for (final entry in raw.entries) {
          final code = entry.key;
          final data = entry.value;
          
          if (data is Map) {
            newProductsMap[code] = FirebaseProductModel.fromSnapshot(code, data);
          }
        }
        _productsMap = newProductsMap;
      }
      _combineData();
    });

    _sgBoxSub = FirebaseDatabase.instance.ref('root/ads/sgBox').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _sgBoxMap = {};
      } else {
        final raw = _safeMap(event.snapshot.value);
        final newSgBoxMap = <String, Map<String, dynamic>>{};
        
        for (final entry in raw.entries) {
          final sysIndex = entry.key;
          final pCodes = _safeMap(entry.value);
          newSgBoxMap[sysIndex] = pCodes;
        }
        _sgBoxMap = newSgBoxMap;
      }
      _combineData();
    });
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is List) {
      final map = <String, dynamic>{};
      for (int i = 0; i < value.length; i++) {
        if (value[i] != null) {
          map[i.toString()] = value[i];
        }
      }
      return map;
    }
    return {};
  }

  void _combineData() {
    if (_stockMap.isEmpty && _productsMap.isEmpty) {
      _isLoading = false;
      _debouncedNotify();
      return;
    }

    final newTrending = <FeedProductModel>[];
    final newBestSellers = <FeedProductModel>[];
    final newSuggestions = <Map<String, dynamic>>[];

    for (final productEntry in _stockMap.entries) {
      final productCode = productEntry.key;
      final variants = productEntry.value;
      final productInfo = _productsMap[productCode];
      
      if (productInfo == null) continue; // Skip if no core product details

      for (final variantEntry in variants.entries) {
        final variantId = variantEntry.key;
        final variant = variantEntry.value;

        if (variant.priorityTrending > 0) {
          newTrending.add(_buildFeedItem(productCode, variantId, productInfo, variant));
        }

        if (variant.priorityBestseller > 0) {
          newBestSellers.add(_buildFeedItem(productCode, variantId, productInfo, variant));
        }
      }
    }

    for (final sgBoxEntry in _sgBoxMap.entries) {
      final indexStr = sgBoxEntry.key;
      final intIndex = int.tryParse(indexStr) ?? 999;
      final productsObj = sgBoxEntry.value;

      for (final productEntry in productsObj.entries) {
        final pCode = productEntry.key;
        final pData = _safeMap(productEntry.value);
        if (pData.isEmpty) continue;

        final info = _productsMap[pCode];
        final variants = _stockMap[pCode];
        
        StockVariantModel? bestVariant;
        String variantId = '';
        if (variants != null && variants.isNotEmpty) {
          variantId = variants.keys.first;
          bestVariant = variants[variantId];
        }

        final customLabel = pData['label name']?.toString() 
                         ?? pData['product name']?.toString() 
                         ?? pData['category name']?.toString() 
                         ?? pData['labelName']?.toString() 
                         ?? '';
        
        final dbProductName = info?.name ?? '';
        final displayLabel = customLabel.isNotEmpty ? customLabel : dbProductName;
        
        final feedItem = FeedProductModel(
          productCode: pCode,
          variantId: variantId,
          name: dbProductName.isNotEmpty ? dbProductName : displayLabel,
          picUrl: info?.picUrl ?? '',
          offerPrice: bestVariant?.offerPrice ?? 0.0,
          mrp: bestVariant?.mrp ?? 0.0,
          unitValue: bestVariant?.unitValue ?? 0.0,
          unit: info?.unit ?? '',
          priorityTrending: bestVariant?.priorityTrending ?? 0,
          priorityBestseller: bestVariant?.priorityBestseller ?? 0,
          labelName: displayLabel.isNotEmpty ? displayLabel : info?.labelName,
        );

        newSuggestions.add({
          'index': intIndex,
          'model': feedItem,
        });
      }
    }

    // Sort by priority descending (highest priority shown first)
    newTrending.sort((a, b) => b.priorityTrending.compareTo(a.priorityTrending));
    newBestSellers.sort((a, b) => b.priorityBestseller.compareTo(a.priorityBestseller));
    // Sort suggestions by index ascending
    newSuggestions.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    _trendingProducts = newTrending;
    _bestSellers = newBestSellers;
    _suggestionBoxItems = newSuggestions.map((e) => e['model'] as FeedProductModel).toList();
    _isLoading = false;

    Perf.end('Firebase', 'SuggestionBox data');
    _precacheFeedImages();
    _debouncedNotify();
  }

  /// Silently warms the image cache for homepage feed products.
  void _precacheFeedImages() {
    final element = WidgetsBinding.instance.rootElement;
    if (element == null) return;

    final urls = <String>{};
    for (final p in [..._trendingProducts, ..._bestSellers]) {
      if (p.picUrl.isNotEmpty) urls.add(p.picUrl);
    }

    for (final url in urls.take(20)) {
      // Use exact URL — must match what OptimizedNetworkImage will request
      precacheImage(
        CachedNetworkImageProvider(url, maxWidth: 200, maxHeight: 200),
        element,
        onError: (_, __) {},
      );
    }
  }

  void _debouncedNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_hasFetched) notifyListeners();
    });
  }

  FeedProductModel _buildFeedItem(
    String productCode, 
    String variantId, 
    FirebaseProductModel info, 
    StockVariantModel stock
  ) {
    return FeedProductModel(
      productCode: productCode,
      variantId: variantId,
      name: info.name,
      picUrl: info.picUrl ?? '',
      offerPrice: stock.offerPrice,
      mrp: stock.mrp,
      unitValue: stock.unitValue,
      unit: info.unit,
      priorityTrending: stock.priorityTrending,
      priorityBestseller: stock.priorityBestseller,
      labelName: info.labelName,
    );
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    _productsSub?.cancel();
    _sgBoxSub?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
