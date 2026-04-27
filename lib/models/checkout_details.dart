class CheckoutDetails {
  final String name;
  final String phone;
  final String address;

  const CheckoutDetails({
    required this.name,
    required this.phone,
    required this.address,
  });

  const CheckoutDetails.empty()
      : name = '',
        phone = '',
        address = '';

  factory CheckoutDetails.fromJson(Map<String, dynamic> json) =>
      CheckoutDetails(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
      };
}
