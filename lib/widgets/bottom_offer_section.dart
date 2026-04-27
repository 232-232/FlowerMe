import 'package:flutter/material.dart';

import '../cart_scope.dart';
import '../cart_controller.dart';
import '../models/product.dart' as app_models;

class OfferItem {
  const OfferItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> colors;
}

class BottomOfferSection extends StatelessWidget {
  const BottomOfferSection({super.key});

  static const List<OfferItem> _trendingItems = [
    OfferItem(
      title: 'Eastern\nCoriander Powder',
      subtitle: '₹16.00 / 100g',
      badge: '30% OFF',
      icon: Icons.grain,
      colors: [Color(0xFFF9F4DD), Color(0xFFEFCB6A)],
    ),
    OfferItem(
      title: 'Eastern\nKashmiri Chilli',
      subtitle: '₹45.00 / 100g',
      badge: '4% OFF',
      icon: Icons.local_fire_department,
      colors: [Color(0xFFF9E2CA), Color(0xFFE85C3E)],
    ),
  ];

  static const List<OfferItem> _exclusiveItems = [
    OfferItem(
      title: 'Cinthol Cool\nFoam Body Wash',
      subtitle: '₹108.00 / 100ml',
      badge: '10% OFF',
      icon: Icons.soap,
      colors: [Color(0xFFD7F6FC), Color(0xFF2DB0DF)],
    ),
    OfferItem(
      title: 'പച്ചരി പൊടി',
      subtitle: '₹299.00 / 1kg',
      badge: '40% OFF',
      icon: Icons.shopping_bag,
      colors: [Color(0xFFFFF0C6), Color(0xFF45A83B)],
    ),
  ];

  static const List<OfferItem> _bestSellerItems = [
    OfferItem(
      title: 'Himalaya Alm...',
      subtitle: '',
      badge: '',
      icon: Icons.spa,
      colors: [Color(0xFFF8E8DC), Color(0xFFD1B399)],
    ),
    OfferItem(
      title: 'Lora Spanish ...',
      subtitle: '',
      badge: '',
      icon: Icons.local_florist,
      colors: [Color(0xFFEFF6CB), Color(0xFFE4B64C)],
    ),
    OfferItem(
      title: 'Rexona Coco...',
      subtitle: '',
      badge: '',
      icon: Icons.health_and_safety,
      colors: [Color(0xFFE4F6C9), Color(0xFF87BB55)],
    ),
    OfferItem(
      title: 'Cinthol Limo...',
      subtitle: '',
      badge: '',
      icon: Icons.local_drink,
      colors: [Color(0xFFBFE7C0), Color(0xFFF7D244)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          _OfferGroup(
            title: 'Trending Now',
            icon: Icons.trending_up_rounded,
            iconBg: const Color(0xFFFF8F3D),
            items: _trendingItems,
          ),
          _SectionDivider(),
          _OfferGroup(
            title: 'Exclusive Offer',
            icon: Icons.sell_rounded,
            iconBg: const Color(0xFFFFC233),
            items: _exclusiveItems,
          ),
          _SectionDivider(),
          _BestSellerGroup(items: _bestSellerItems),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      height: 1,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

class _OfferGroup extends StatelessWidget {
  const _OfferGroup({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final List<OfferItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE7E9E5),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _OfferCard(item: items[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.item});

  final OfferItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductArt(
                      width: 58,
                      height: 72,
                      icon: item.icon,
                      colors: item.colors,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF323232),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5A3A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Text(
                item.badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 6,
            child: _PlusCircle(
              onTap: () => _addToCart(context, item),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(BuildContext context, OfferItem offer) {
    final CartController cart = CartScope.of(context);

    final double price = _parsePrice(offer.subtitle);
    final app_models.Product product = app_models.Product(
      name: offer.title.replaceAll('\n', ' '),
      weight: offer.subtitle.isEmpty ? '1 unit' : offer.subtitle,
      image: '',
      price: price,
      oldPrice: price,
      discount: 0,
    );

    cart.add(product, 1);
    cart.triggerBounce();
    cart.showAddedBar();
  }

  double _parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

class _BestSellerGroup extends StatelessWidget {
  const _BestSellerGroup({required this.items});

  final List<OfferItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1D04C),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Our Best Sellers',
                style: TextStyle(
                  color: Color(0xFFE7E9E5),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _BestSellerCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  const _BestSellerCard({required this.item});

  final OfferItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _ProductArt(
                width: double.infinity,
                height: double.infinity,
                icon: item.icon,
                colors: item.colors,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductArt extends StatelessWidget {
  const _ProductArt({
    required this.width,
    required this.height,
    required this.icon,
    required this.colors,
  });

  final double width;
  final double height;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlusCircle extends StatelessWidget {
  const _PlusCircle({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF34A45D),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }
}
