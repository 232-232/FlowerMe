import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firebase_product_model.dart';

class RecentSearchProvider extends ChangeNotifier {
  static const String _key = 'recent_products_v1';
  List<FirebaseProductModel> _recentItems = [];
  bool _initialized = false;

  List<FirebaseProductModel> get recentItems => _recentItems;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    
    // We store them as JSON strings for simplicity
    _recentItems = raw.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return FirebaseProductModel.fromSnapshot(map['code'] as String, map['data'] as Map<Object?, Object?>);
      } catch (e) {
        return null;
      }
    }).whereType<FirebaseProductModel>().toList();
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> addItem(FirebaseProductModel product) async {
    // Remove if already exists to move to top
    _recentItems.removeWhere((item) => item.code == product.code);
    _recentItems.insert(0, product);
    
    // Limit to 10
    if (_recentItems.length > 10) {
      _recentItems = _recentItems.sublist(0, 10);
    }
    
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _recentItems.map((item) {
      // Create a simplified Map for serialization
      return jsonEncode({
        'code': item.code,
        'data': {
          'name': item.name,
          'price': item.price,
          'pic': item.picUrl,
          'categoryCode': item.categoryCode,
          'originalPrice': item.originalPrice,
          'discount': item.discount,
          'weight': item.weight,
          'unit': item.unit,
          'details': item.details,
          'labelName': item.labelName,
        },
      });
    }).toList();
    await prefs.setStringList(_key, raw);
  }
}
