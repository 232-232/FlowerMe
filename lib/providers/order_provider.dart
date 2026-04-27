import 'package:flutter/foundation.dart';

import '../models/checkout_details.dart';
import '../models/order_model.dart';
import '../services/local_storage_service.dart';

class OrderProvider extends ChangeNotifier {
  static const String _key = 'orders_list';

  List<OrderModel> _orders = [];

  List<OrderModel> get allOrders => List.unmodifiable(_orders);

  List<OrderModel> get deliveredOrders =>
      _orders.where((o) => o.status == 'delivered').toList();

  List<OrderModel> get activeOrders => _orders
      .where((o) => o.status != 'delivered' && o.status != 'cancelled' && o.status != 'deleted')
      .toList();

  int get deliveredCount =>
      _orders.where((o) => o.status == 'delivered').length;

  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadOrders() async {
    final json = await LocalStorageService.getString(_key);
    if (json != null && json.isNotEmpty) {
      try {
        _orders = OrderModel.decodeList(json);
      } catch (_) {
        _orders = [];
      }
    }

    if (_orders.isEmpty) {
      _seedDemoOrders();
      await _persist();
    }
  }

  void addOrder(OrderModel order) {
    _orders.insert(0, order);
    notifyListeners();
    _persist();
  }

  /// Updates order status by orderId and persists.
  void updateOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;

    DateTime? deliveredAt;
    if (newStatus == 'delivered') {
      deliveredAt = DateTime.now();
    }

    _orders[index] = _orders[index].copyWith(
      status: newStatus,
      deliveredAt: deliveredAt,
    );
    notifyListeners();
    _persist();
  }

  /// Cancels the order with [orderId], recording the [reason].
  void cancelOrder(String orderId, String reason) {
    final index = _orders.indexWhere((o) => o.orderId == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(
      status: 'cancelled',
      cancelReason: reason,
    );
    notifyListeners();
    _persist();
  }

  void _seedDemoOrders() {
    final now = DateTime.now();
    const demoDetails = CheckoutDetails(
      name: 'Mubinsha',
      phone: '+91 7593033563',
      address: 'Kadavath House, Wayanad, Kerala',
    );

    _orders = [
      OrderModel(
        orderId: 'DC92841',
        items: const [
          OrderItemModel(name: 'Aachi Chilli Powder', price: 72, quantity: 2),
          OrderItemModel(
              name: 'Brahmins Garam Masala', price: 31, quantity: 1),
        ],
        totalPrice: 175,
        quantity: 3,
        orderDateTime: now.subtract(const Duration(days: 3, hours: 2)),
        status: 'delivered',
        deliveryDetails: demoDetails,
        paymentMethod: 'cod',
      ),
      OrderModel(
        orderId: 'DC91037',
        items: const [
          OrderItemModel(
              name: 'Eastern Coriander Powder', price: 16, quantity: 1),
          OrderItemModel(
              name: 'Tasty Nibbles Coconut Milk', price: 38, quantity: 2),
          OrderItemModel(name: 'Matta Rice', price: 54, quantity: 1),
        ],
        totalPrice: 175,
        quantity: 4,
        orderDateTime: now.subtract(const Duration(days: 10, hours: 4)),
        status: 'delivered',
        deliveryDetails: demoDetails,
        paymentMethod: 'upi',
      ),
      OrderModel(
        orderId: 'DC88320',
        items: const [
          OrderItemModel(name: 'Good Life Sugar', price: 49, quantity: 1),
          OrderItemModel(name: 'Milma Ghee', price: 315, quantity: 1),
        ],
        totalPrice: 393,
        quantity: 2,
        orderDateTime: now.subtract(const Duration(days: 17, hours: 1)),
        status: 'delivered',
        deliveryDetails: demoDetails,
        paymentMethod: 'cod',
      ),
    ];
  }

  Future<void> _persist() async {
    await LocalStorageService.setString(_key, OrderModel.encodeList(_orders));
  }
}
