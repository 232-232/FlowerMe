class OrderItem {
  final String name;
  final double price;
  final int quantity;

  const OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  @override
  String toString() =>
      'OrderItem(name: $name, price: $price, quantity: $quantity)';
}

