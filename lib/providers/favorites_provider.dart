import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/product.dart';
import '../models/firebase_product_model.dart';
import '../services/local_storage_service.dart';
import '../data/items_catalog.dart';

class FavoritesProvider extends ChangeNotifier {
  static const String _key = 'favorites_products_v2';
  static const String _oldKey = 'favorites_ids';

  final Map<String, Product> _favorites = {};
  String _lastSyncedPhone = '';

  bool isFavorite(String productName) => _favorites.containsKey(productName);

  Set<String> get favoriteIds => _favorites.keys.toSet();

  List<Product> get favoritesList => _favorites.values.toList();

  int get count => _favorites.length;

  void toggle(Product product) {
    if (_favorites.containsKey(product.name)) {
      _favorites.remove(product.name);
    } else {
      _favorites[product.name] = product;
    }
    notifyListeners();
    _persist();
  }

  void add(Product product) {
    if (!_favorites.containsKey(product.name)) {
      _favorites[product.name] = product;
      notifyListeners();
      _persist();
    }
  }

  void remove(String productName) {
    if (_favorites.remove(productName) != null) {
      notifyListeners();
      _persist();
    }
  }

  Future<void> syncWithFirebase(String phone) async {
    final p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10) return;
    final num = p.substring(p.length - 10);
    
    if (_lastSyncedPhone == num) return;
    _lastSyncedPhone = num;

    try {
      final snapshot = await FirebaseDatabase.instance.ref('root/userpersonalize/$num/favorite').once();
      if (!snapshot.snapshot.exists || snapshot.snapshot.value == null) {
        if (_favorites.isNotEmpty) {
          _favorites.clear();
          await _persist();
          notifyListeners();
        }
        return;
      }

      final raw = snapshot.snapshot.value as Map<Object?, Object?>;
      _favorites.clear();
      
      for (final docId in raw.keys) {
        final safeId = docId.toString();
        final productCode = safeId.replaceAll('_', '.');
        
        final prodSnapshot = await FirebaseDatabase.instance.ref('root/products/$productCode').once();
        if (prodSnapshot.snapshot.exists && prodSnapshot.snapshot.value != null) {
          final fbProduct = FirebaseProductModel.fromSnapshot(productCode, prodSnapshot.snapshot.value);
          final product = Product(
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
          
          _favorites[product.name] = product;
        }
      }
      
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing favorites from firebase: $e');
    }
  }

  Future<void> loadFavorites() async {
    // 1. Try to load V2 (full models)
    final v2Json = await LocalStorageService.getString(_key);
    if (v2Json != null && v2Json.isNotEmpty) {
      try {
        final data = jsonDecode(v2Json) as Map<String, dynamic>;
        data.forEach((key, value) {
          _favorites[key] = Product.fromMap(value as Map<String, dynamic>);
        });
        if (_favorites.isNotEmpty) return;
      } catch (e) {
        debugPrint('Error loading favorites v2: $e');
      }
    }

    // 2. Migration from V1 (ids only)
    final v1Json = await LocalStorageService.getString(_oldKey);
    if (v1Json != null && v1Json.isNotEmpty) {
      try {
        final list = jsonDecode(v1Json) as List<dynamic>;
        final allPossibleProducts = ItemsCatalog.allProducts;
        for (final id in list.cast<String>()) {
          // Skip the default mock Matta Rice since it's being replaced by actual items
          if (id == 'Matta Rice') continue;
          
          final p = allPossibleProducts.firstWhere(
            (p) => p.name == id,
            orElse: () => const Product(
              name: '',
              weight: '',
              image: '',
              price: 0,
              oldPrice: 0,
              discount: 0,
            ),
          );
          if (p.name.isNotEmpty) {
            _favorites[p.name] = p;
          }
        }
        if (_favorites.isNotEmpty) {
          await _persist();
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final Map<String, dynamic> data = {};
    _favorites.forEach((key, value) {
      data[key] = value.toMap();
    });
    await LocalStorageService.setString(_key, jsonEncode(data));
  }
}
