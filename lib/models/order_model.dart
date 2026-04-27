import 'dart:convert';

import 'checkout_details.dart';

class OrderItemModel {
  final String name;
  final double price;
  final int quantity;
  final String? productCode;

  const OrderItemModel({
    required this.name,
    required this.price,
    required this.quantity,
    this.productCode,
  });

  double get total => price * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        productCode: json['productCode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
        'productCode': productCode,
      };
}

/// Valid status strings:
/// orderPlaced | packed | outForDelivery | arriving | delivered | cancelled
class OrderModel {
  final String orderId;
  final List<OrderItemModel> items;
  final double totalPrice;
  final int quantity;
  final DateTime orderDateTime;
  final String status;
  final CheckoutDetails deliveryDetails;
  final String paymentMethod; // 'cod' | 'upi'
  final String deliveryInstruction;
  final String? cancelReason;
  final DateTime? deliveredAt;

  const OrderModel({
    required this.orderId,
    required this.items,
    required this.totalPrice,
    required this.quantity,
    required this.orderDateTime,
    required this.status,
    required this.deliveryDetails,
    this.paymentMethod = 'cod',
    this.deliveryInstruction = '',
    this.cancelReason,
    this.deliveredAt,
  });

  OrderModel copyWith({
    String? status,
    String? cancelReason,
    DateTime? deliveredAt,
  }) =>
      OrderModel(
        orderId: orderId,
        items: items,
        totalPrice: totalPrice,
        quantity: quantity,
        orderDateTime: orderDateTime,
        status: status ?? this.status,
        deliveryDetails: deliveryDetails,
        paymentMethod: paymentMethod,
        deliveryInstruction: deliveryInstruction,
        cancelReason: cancelReason ?? this.cancelReason,
        deliveredAt: deliveredAt ?? this.deliveredAt,
      );

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        orderId: json['orderId'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPrice: (json['totalPrice'] as num).toDouble(),
        quantity: json['quantity'] as int,
        orderDateTime: DateTime.parse(json['orderDateTime'] as String),
        status: json['status'] as String,
        deliveryDetails: json['deliveryDetails'] != null
            ? CheckoutDetails.fromJson(
                json['deliveryDetails'] as Map<String, dynamic>)
            : const CheckoutDetails.empty(),
        paymentMethod: json['paymentMethod'] as String? ?? 'cod',
        deliveryInstruction:
            json['deliveryInstruction'] as String? ?? '',
        deliveredAt: json['deliveredAt'] != null
            ? DateTime.parse(json['deliveredAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'items': items.map((e) => e.toJson()).toList(),
        'totalPrice': totalPrice,
        'quantity': quantity,
        'orderDateTime': orderDateTime.toIso8601String(),
        'status': status,
        'deliveryDetails': deliveryDetails.toJson(),
        'paymentMethod': paymentMethod,
        'deliveryInstruction': deliveryInstruction,
        'cancelReason': cancelReason,
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  static String encodeList(List<OrderModel> orders) =>
      jsonEncode(orders.map((o) => o.toJson()).toList());

  static List<OrderModel> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
