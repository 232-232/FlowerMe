import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/checkout_details.dart';
import '../models/order_model.dart';

/// ```
class FirebaseOrderService {
  static final DatabaseReference _root = FirebaseDatabase.instance.ref(
    'root/order',
  );

  // ── Status string constants (as stored in Firebase) ─────────────────────────
  static const String statusOrderPlaced = 'order placed';
  static const String statusPacked = 'packed';
  static const String statusOutForDelivery = 'out for delivery';
  static const String statusArriving = 'arriving';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';

  // ── Firebase status → local app status mapping ───────────────────────────────
  static String firebaseToAppStatus(String? firebaseStatus) {
    if (firebaseStatus == null) return 'deleted';
    switch (firebaseStatus.toLowerCase().trim()) {
      case 'packed':
        return 'packed';
      case 'out for delivery':
        return 'outForDelivery';
      case 'arriving':
        return 'arriving';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      case 'deleted':
        return 'deleted';
      case 'order placed':
      default:
        return 'orderPlaced';
    }
  }

  /// Atomically increments the order counter (starting at 100) and writes
  /// the full order payload in a single transaction.
  ///
  /// Returns the assigned order number (e.g. 100, 101, …) or throws on error.
  /// Atomically increments the order counter, writes the order payload,
  /// and decrements stock quantities in a single atomic set of operations.
  ///
  /// [stockUpdates] should be a list of maps:
  /// `[{ 'productCode': '...', 'variantId': '...', 'count': 5 }]`
  static Future<int> placeOrder({
    required String name,
    required String phone,
    required String address,
    required List<Map<String, String>> items,
    required List<Map<String, dynamic>> stockUpdates,
    double? walletDeductionAmount,
    String? paymentMethod,
  }) async {
    final counterRef = _root.child('counter');

    if (!kIsWeb) {
      await counterRef.keepSynced(true);
    }

    // ── 1. Determine baseline by peeking at existing orders ──────────────────
    // Self-healing: Ensure we never restart from 101 if numeric orders exist.
    int baseline = 100;
    try {
      final lastOrdersSnap = await _root
          .limitToLast(10)
          .get()
          .timeout(const Duration(seconds: 4));
      if (lastOrdersSnap.exists && lastOrdersSnap.value is Map) {
        final data = lastOrdersSnap.value as Map;
        for (final key in data.keys) {
          final int? numericId = int.tryParse(key.toString());
          if (numericId != null && numericId > baseline) {
            baseline = numericId;
          }
        }
      }
    } catch (_) {
      // Optional peek failed (timeout/network); transaction will still attempt correctness.
    }

    // ── 2. Atomically get-and-increment the counter node ─────────────────────
    int orderNumber;
    try {
      final result = await counterRef
          .runTransaction((Object? current) {
            int serverVal = 100;
            if (current != null) {
              serverVal = current is int
                  ? current
                  : (int.tryParse(current.toString()) ?? 100);
            }
            // Always increment beyond the max of the counter node and the found baseline.
            final int nextVal =
                (serverVal > baseline ? serverVal : baseline) + 1;
            return Transaction.success(nextVal);
          })
          .timeout(const Duration(seconds: 6));

      if (result.committed && result.snapshot.value != null) {
        orderNumber = int.parse(result.snapshot.value.toString());
      } else {
        orderNumber = baseline + 1;
      }
    } catch (e) {
      // If transaction times out, use the baseline + 1 as the safest next ID.
      orderNumber = baseline + 1;
      // Note: We don't set counterRef here to avoid race conditions during a timeout.
    }

    // ── 3. Build the payloads ────────────────────────────────────────────────
    final now = DateTime.now().toUtc().toIso8601String();
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final last10Digits = digitsOnly.length > 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    final phoneInt = int.tryParse(last10Digits) ?? 0;

    final Map<String, dynamic> orderData = {
      'name': name,
      'phnm': phoneInt,
      'adrs': address,
      'status': statusOrderPlaced,
      'status_updated_at': now,
    };

    if (paymentMethod != null) {
      orderData['paymentMethod'] = paymentMethod;
    }

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final label = item['variantLabel']?.isNotEmpty == true
          ? '${item['name']} - ${item['variantLabel']}'
          : item['name'] ?? '';

      final price = item['price'];
      final qty = int.tryParse(item['quantity'] ?? '1') ?? 1;

      if (price != null && price.isNotEmpty) {
        final unitPrice = double.tryParse(price) ?? 0;
        final totalPrice = (unitPrice * qty).round();
        if (qty > 1) {
          // Format: 2X-Aval-92RS(2X46RS)
          orderData['item${i + 1}'] =
              '${qty}X-$label-${totalPrice}RS(${qty}X${price}RS)';
        } else {
          orderData['item${i + 1}'] = '$label-${price}RS';
        }
      } else {
        orderData['item${i + 1}'] = qty > 1 ? '${qty}X-$label' : label;
      }

      // Add item ID field (e.g., item1id, item2id)
      final pCode = item['productCode'] ?? '';
      final vId = item['variantId'] ?? 'base';
      orderData['item${i + 1}id'] = vId != 'base' ? '$pCode-$vId' : pCode;
    }

    // ── 4. Build multi-path update map (Atomicity) ──────────────────────────
    final Map<String, dynamic> updates = {};

    // Path for the new order
    updates['root/order/$orderNumber'] = orderData;

    // Path for quick user order lookup
    updates['root/userorders/$last10Digits/$orderNumber'] = orderData;

    // Path for wallet orders
    if (paymentMethod != null && paymentMethod.startsWith('wallet')) {
      updates['root/walletOrders/$last10Digits/$orderNumber'] = orderData;
    }

    // Paths for stock decrements
    for (final update in stockUpdates) {
      final pCode = update['productCode'];
      final vId = update['variantId'];
      final count = update['count'] as int;

      if (pCode != null && vId != null && count > 0) {
        // Use ServerValue.increment to avoid race conditions
        updates['root/stock/$pCode/$vId/quantity'] = ServerValue.increment(
          -count,
        );
      }
    }

    // Perform the atomic multi-path update
    if (walletDeductionAmount != null) {
      final walletUserId = last10Digits;
      final walletSnap = await FirebaseDatabase.instance
          .ref('root/walletusers/$walletUserId')
          .get();

      updates['root/walletusers/$walletUserId/walletEnabled'] = true;
      if (!walletSnap.exists) {
        updates['root/walletusers/$walletUserId/walletBalance'] =
            1000.0 - walletDeductionAmount;
      } else {
        updates['root/walletusers/$walletUserId/walletBalance'] =
            ServerValue.increment(-walletDeductionAmount);
      }
    }

    await FirebaseDatabase.instance.ref().update(updates);

    return orderNumber;
  }

  /// Returns a [StreamSubscription] that fires the [onStatusChange] callback
  /// every time `order/{orderNumber}/status` changes in Firebase.
  ///
  /// The callback receives the raw Firebase status string (e.g. "packed") or null if deleted.
  /// Call `.cancel()` on the returned subscription when done.
  static StreamSubscription<DatabaseEvent> listenToStatus(
    int orderNumber,
    void Function(String? firebaseStatus) onStatusChange,
  ) {
    return _root
        .child('$orderNumber/status')
        .onValue
        .listen(
          (DatabaseEvent event) {
            final raw = event.snapshot.value;
            if (raw == null) {
              onStatusChange(null);
            } else if (raw is String) {
              onStatusChange(raw);
            }
          },
          onError: (_) {
            // Silently ignore network errors — the UI will just keep the last status.
          },
        );
  }

  /// Cancels / updates the order status in Firebase (used for cancel flow).
  static Future<void> updateStatus(
    int orderNumber,
    String firebaseStatus,
  ) async {
    await _root.child('$orderNumber').update({
      'status': firebaseStatus,
      'status_updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Submits a user rating and review to root/rating/{orderNumber}.
  static Future<void> submitRating({
    required int orderNumber,
    required String name,
    required int phoneNumber,
    required double rating,
    required String review,
    required List<String> items,
    required String totalTime, // e.g. "14 mins"
  }) async {
    final ratingRef = FirebaseDatabase.instance.ref('root/rating/$orderNumber');
    await ratingRef.set({
      'name': name,
      'phnum': phoneNumber,
      'rating': rating,
      'review': review,
      'items': items,
      'total_time': totalTime,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Fetches order history for a specific phone number.
  static Future<List<OrderModel>> fetchUserOrders(String phone) async {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final last10Digits = digitsOnly.length > 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
    debugPrint('--- DEBUG: FirebaseOrderService fetchUserOrders checking for phone: "$last10Digits" ---');
    if (last10Digits.length < 10) return [];

    final snap = await FirebaseDatabase.instance.ref('root/userorders/$last10Digits').get();
    debugPrint('--- DEBUG: FirebaseOrderService Snapshot exists: ${snap.exists}, value = ${snap.value} ---');
    if (!snap.exists || snap.value == null) return [];

    final snapValue = snap.value;
    Iterable<MapEntry<dynamic, dynamic>> entries;

    if (snapValue is Map) {
      entries = snapValue.entries;
    } else if (snapValue is List) {
      entries = snapValue.asMap().entries.where((e) => e.value != null);
    } else {
      return [];
    }

    final List<OrderModel> orders = [];

    for (final entry in entries) {
      final orderIdStr = entry.key.toString();
      final data = entry.value as Map<dynamic, dynamic>;

      final List<OrderItemModel> items = [];
      double totalPrice = 0.0;
      int totalQty = 0;

      for (int i = 1; i <= 100; i++) {
        final itemStr = data['item$i'] as String?;
        if (itemStr == null) break;

        int qty = 1;
        String name = itemStr;
        double price = 0.0;

        if (RegExp(r'^(\d+)X-').hasMatch(itemStr)) {
          final match = RegExp(r'^(\d+)X-').firstMatch(itemStr);
          if (match != null) {
            qty = int.tryParse(match.group(1)!) ?? 1;
            name = itemStr.substring(match.end);
          }
        }

        if (name.contains('-')) {
          final lastDash = name.lastIndexOf('-');
          final pricePart = name.substring(lastDash + 1);
          if (pricePart.contains('RS')) {
            name = name.substring(0, lastDash);
            final rsMatch = RegExp(r'^(\d+)RS').firstMatch(pricePart);
            if (rsMatch != null) {
              final totalItemPrice = double.tryParse(rsMatch.group(1)!) ?? 0.0;
              price = totalItemPrice / qty;
            }
          }
        }

        totalPrice += (price * qty);
        totalQty += qty;
        
        final itemIdStr = data['item${i}id'] as String?;
        String? productCode;
        if (itemIdStr != null && itemIdStr.isNotEmpty) {
          final parts = itemIdStr.split('-');
          productCode = parts[0];
        }

        items.add(OrderItemModel(name: name, price: price, quantity: qty, productCode: productCode));
      }

      final status = firebaseToAppStatus(data['status']?.toString());
      final updatedAtStr = data['status_updated_at']?.toString();
      final orderDateTime = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) ?? DateTime.now() : DateTime.now();

      final deliveryDetails = CheckoutDetails(
        name: data['name']?.toString() ?? '',
        phone: data['phnm']?.toString() ?? '',
        address: data['adrs']?.toString() ?? '',
      );

      DateTime? deliveredAt;
      if (status == 'delivered') {
        deliveredAt = orderDateTime;
      }

      final rawPaymentMethod = data['paymentMethod']?.toString() ?? 'cod';
      final cleanPaymentMethod = rawPaymentMethod.split('-').first.toLowerCase();

      orders.add(OrderModel(
        orderId: 'DC$orderIdStr',
        items: items,
        totalPrice: totalPrice,
        quantity: totalQty,
        orderDateTime: orderDateTime,
        status: status,
        deliveryDetails: deliveryDetails,
        paymentMethod: cleanPaymentMethod,
        deliveredAt: deliveredAt,
      ));
    }

    orders.sort((a, b) => b.orderDateTime.compareTo(a.orderDateTime));
    return orders;
  }
}
