import '../models/product.dart';

abstract final class ItemsCatalog {
  ItemsCatalog._();

  static const List<String> categories = [
    'പാചകക്കുറി',
    'മസാല',
    'കുടുംബം',
    'കൂടുതൽ പാലും',
  ];

  static const String defaultCategory = 'മസാല';
  static const String cartProductName = 'Aachi Chilli Powder';

  static const Map<String, List<Product>> _productsByCategory = {
    'പാചകക്കുറി': [
      Product(
        name: 'Tasty Nibbles Coconut Milk',
        weight: '200ml',
        image: 'https://picsum.photos/seed/coconut-milk/240/240',
        price: 38.00,
        oldPrice: 48.00,
        discount: 21,
      ),
      Product(
        name: 'Double Horse Meat Masala',
        weight: '100g',
        image: 'https://picsum.photos/seed/meat-masala/240/240',
        price: 42.00,
        oldPrice: 54.00,
        discount: 22,
      ),
      Product(
        name: 'Brahmins Garam Masala',
        weight: '100g',
        image: 'https://picsum.photos/seed/garam-masala/240/240',
        price: 31.00,
        oldPrice: 40.00,
        discount: 23,
      ),
      Product(
        name: 'Aachi Chicken Masala',
        weight: '200g',
        image: 'https://picsum.photos/seed/chicken-masala/240/240',
        price: 54.00,
        oldPrice: 70.00,
        discount: 23,
      ),
    ],
    'മസാല': [
      Product(
        name: 'Eastern Coriander Powder',
        weight: '100g',
        image: 'https://picsum.photos/seed/coriander-powder/240/240',
        price: 16.00,
        oldPrice: 23.00,
        discount: 24,
      ),
      Product(
        name: 'Aachi Chilli Powder',
        weight: '250g',
        image: 'https://picsum.photos/seed/chilli-powder/240/240',
        price: 72.00,
        oldPrice: 96.00,
        discount: 25,
      ),
      Product(
        name: 'Brahmins Turmeric Powder',
        weight: '100g',
        image: 'https://picsum.photos/seed/turmeric-powder/240/240',
        price: 18.00,
        oldPrice: 25.00,
        discount: 28,
      ),
      Product(
        name: 'Double Horse Pepper Powder',
        weight: '100g',
        image: 'https://picsum.photos/seed/pepper-powder/240/240',
        price: 36.00,
        oldPrice: 44.00,
        discount: 18,
      ),
    ],
    'കുടുംബം': [
      Product(
        name: 'Matta Rice',
        weight: '1 kg',
        image: 'https://picsum.photos/seed/matta-rice/240/240',
        price: 54.00,
        oldPrice: 70.00,
        discount: 23,
        description:
            'നാരസമ്പുഷ്ടവും ഗുണനിലവാരമുള്ളതുമായ മട്ട അരി, കേരളത്തിൻ്റെ പരമ്പരാഗത ഭക്ഷണത്തിന് രുചിയും പോഷകവും പകരുന്ന ഒരു ആരോഗ്യകരമായ തിരഞ്ഞെടുപ്പാണ്.',
        variants: const [
          ProductVariant(variantId: '0', label: '1 kg', price: 54.00, oldPrice: 70.00),
          ProductVariant(variantId: '1', label: '10 kg', price: 490.00, oldPrice: 650.00),
        ],
      ),
      Product(
        name: 'Milma Ghee',
        weight: '500ml',
        image: 'https://picsum.photos/seed/milma-ghee/240/240',
        price: 315.00,
        oldPrice: 360.00,
        discount: 13,
      ),
      Product(
        name: 'Aashirvaad Atta',
        weight: '1kg',
        image: 'https://picsum.photos/seed/atta-pack/240/240',
        price: 54.00,
        oldPrice: 63.00,
        discount: 14,
      ),
      Product(
        name: 'Good Life Sugar',
        weight: '1kg',
        image: 'https://picsum.photos/seed/sugar-pack/240/240',
        price: 49.00,
        oldPrice: 58.00,
        discount: 16,
      ),
      Product(
        name: 'Idhayam Sesame Oil',
        weight: '500ml',
        image: 'https://picsum.photos/seed/sesame-oil/240/240',
        price: 159.00,
        oldPrice: 188.00,
        discount: 15,
      ),
    ],
    'കൂടുതൽ പാലും': [
      Product(
        name: 'Milky Mist Paneer Cubes',
        weight: '200g',
        image: 'https://picsum.photos/seed/paneer-pack/240/240',
        price: 86.00,
        oldPrice: 104.00,
        discount: 17,
      ),
      Product(
        name: 'Amul Fresh Cream',
        weight: '250ml',
        image: 'https://picsum.photos/seed/fresh-cream/240/240',
        price: 64.00,
        oldPrice: 78.00,
        discount: 18,
      ),
      Product(
        name: 'Milma Curd',
        weight: '500g',
        image: 'https://picsum.photos/seed/curd-cup/240/240',
        price: 42.00,
        oldPrice: 48.00,
        discount: 13,
      ),
      Product(
        name: 'Britannia Cheese Slices',
        weight: '100g',
        image: 'https://picsum.photos/seed/cheese-slices/240/240',
        price: 108.00,
        oldPrice: 126.00,
        discount: 14,
      ),
    ],
  };

  static List<Product> productsFor(String category) {
    return _productsByCategory[category] ??
        _productsByCategory[defaultCategory]!;
  }

  static List<Product> get allProducts =>
      _productsByCategory.values.expand((l) => l).toList();
}
