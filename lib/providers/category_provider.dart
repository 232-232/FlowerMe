import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

import '../debug/dc_log.dart';
import '../debug/perf_logger.dart';
import '../models/category_model.dart';
import '../services/local_storage_service.dart';

class CategoryProvider {
  CategoryProvider._();

  static const String _localCacheKey = 'persistent_category_cache';
  static List<CategoryModel>? _cache;

  static bool get hasCache => _cache != null && _cache!.isNotEmpty;
  static List<CategoryModel>? get cachedCategories => _cache;

  /// Precaches images for the first [limit] categories silently in the background.
  static void _precacheImages(List<CategoryModel> categories, {int limit = 20}) {
    final element = WidgetsBinding.instance.rootElement;
    if (element == null) return;
    final int count = categories.length < limit ? categories.length : limit;
    for (int i = 0; i < count; i++) {
      final url = categories[i].picUrl;
      if (url == null || url.isEmpty) continue;
      // Use exact URL — matches what OptimizedNetworkImage will request
      precacheImage(
        CachedNetworkImageProvider(url, maxWidth: 148, maxHeight: 148),
        element,
        onError: (_, __) {},
      );
    }
  }

  static Future<List<CategoryModel>> getCategoriesOnce() async {
    if (_cache != null) {
      // Force sort cache for hot reload scenario
      _cache!.sort((a, b) => a.ratingKey.compareTo(b.ratingKey));
      return _cache!;
    }

    // 1. Check LocalStorage for instant 0ms startup
    try {
      final cachedJson = await LocalStorageService.getString(_localCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(cachedJson);
        final localCategories = rawList.map((e) {
          final m = e as Map<String, dynamic>;
          return CategoryModel(
            code: m['code'] as String,
            name: m['name'] as String,
            picUrl: m['picUrl'] as String?,
            ratingKey: m['ratingKey'] as int? ?? 999,
          );
        }).toList();

        if (localCategories.isNotEmpty) {
          // If the cache was saved before we added ratingKey, bypass it.
          if (localCategories.every((c) => c.ratingKey == 999)) {
            dcLog('Firebase', '⚠️ Old cache detected (missing ratingKey). Bypassing cache to fetch fresh sorted data.');
            return await _fetchAndPersistSilent(isBlocking: true);
          }

          localCategories.sort((a, b) => a.ratingKey.compareTo(b.ratingKey));
          _cache = localCategories;
          dcLog('Firebase', '⚡ Instantly loaded ${localCategories.length} categories from persistent storage');
          // Prefetch images immediately so they’re warm by the time the grid renders
          _precacheImages(localCategories);
          // Silently update cache behind the scenes for the next boot
          _fetchAndPersistSilent();
          return localCategories;
        }
      }
    } catch (_) {
      // Fallback if local storage decode fails
    }

    // 2. Original Network Fetch Fallback
    Perf.start('Firebase', 'CategoryGrid data');
    return await _fetchAndPersistSilent(isBlocking: true);
  }

  static Future<List<CategoryModel>> _fetchAndPersistSilent({bool isBlocking = false}) async {
    final ref = FirebaseDatabase.instance.ref('root/category');
    if (!isBlocking) {
      dcLog('Firebase', '🔌 Silently connecting to root/category in background…');
    } else {
      dcLog('Firebase', '🔌 Connecting to root/category …');
    }

    final snapshot = await ref.get();

    if (!snapshot.exists || snapshot.value == null) {
      dcLog('Firebase', '⚠️  root/category snapshot is empty');
      Perf.end('Firebase', 'CategoryGrid data');
      return <CategoryModel>[];
    }

    dcLog('Firebase', '✅ Connected — snapshot received from root/category');

    final raw = snapshot.value as Map<Object?, Object?>;
    final categories = <CategoryModel>[];

    for (final entry in raw.entries) {
      final code = entry.key?.toString() ?? '';
      final data = entry.value;

      if (data is Map<Object?, Object?>) {
        final name = (data['name'] as String?) ?? code;
        final pic  = data['pic']  as String?;

        dcLog('Category', '📦 [$code] name: "$name"');
        if (pic != null && pic.isNotEmpty) {
          dcLog('Category', '🖼️  [$code] pic : $pic');
        } else {
          dcLog('Category', '🚫 [$code] pic : (none)');
        }

        categories.add(CategoryModel.fromSnapshot(code, data));
      }
    }

    dcLog('Firebase', '📋 Total categories loaded: ${categories.length}');
    categories.sort((a, b) => a.ratingKey.compareTo(b.ratingKey));
    _cache = categories;
    // Prefetch images immediately after network load
    _precacheImages(categories);

    // Persist to local storage
    try {
      final jsonList = categories.map((c) => {
        'code': c.code,
        'name': c.name,
        'picUrl': c.picUrl,
        'ratingKey': c.ratingKey,
      }).toList();
      await LocalStorageService.setString(_localCacheKey, jsonEncode(jsonList));
    } catch (_) {}

    if (isBlocking) {
      Perf.end('Firebase', 'CategoryGrid data');
    } else {
      dcLog('Firebase', '✅ Background category cache updated successfully.');
    }
    
    return categories;
  }
}
