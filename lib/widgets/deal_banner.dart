import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/firebase_product_model.dart';
import '../models/product.dart';
import '../pages/product_details_page.dart';
import '../pages/items_page.dart';
import 'package:flutter/cupertino.dart';
import 'optimized_network_image.dart';
import '../utils/share_helper.dart';

class DealBannerSection extends StatefulWidget {
  const DealBannerSection({super.key});

  @override
  State<DealBannerSection> createState() => _DealBannerSectionState();
}

class _DealBannerSectionState extends State<DealBannerSection> {
  StreamSubscription? _adsSubscription;
  List<Map<String, dynamic>> _deals = [];
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (Firebase.apps.isNotEmpty) {
      _adsSubscription = FirebaseDatabase.instance
          .ref('root/ads/exclusive')
          .onValue
          .listen((event) {
            if (!event.snapshot.exists || event.snapshot.value == null) {
              if (mounted) setState(() => _deals = []);
              return;
            }

            final dynamic raw = event.snapshot.value;
            final newDeals = <Map<String, dynamic>>[];

            void extractDeal(dynamic data) {
              if (data is Map<Object?, Object?> ||
                  data is Map<String, dynamic>) {
                final Map<dynamic, dynamic> mapData =
                    data as Map<dynamic, dynamic>;

                final Map<String, dynamic> lowerMap = {};
                mapData.forEach((key, value) {
                  lowerMap[key.toString().toLowerCase()] = value;
                });

                Color parseColor(String raw, Color defaultColor) {
                  String str = raw.trim();
                  if (str.isEmpty) return defaultColor;
                  if (str.startsWith('#')) {
                    str = str.replaceFirst(
                      '#',
                      str.length == 7 ? '0xff' : '0x',
                    );
                  } else if (!str.startsWith('0x') && str.length == 6) {
                    str = '0xff$str';
                  } else if (!str.startsWith('0x') && str.length == 8) {
                    str = '0x$str';
                  }
                  try {
                    return Color(int.parse(str));
                  } catch (_) {
                    return defaultColor;
                  }
                }

                final bgColor1 = parseColor(
                  lowerMap['bgcolor1']?.toString() ?? '',
                  const Color(0xff7C3AED),
                );
                final bgColor2 = parseColor(
                  lowerMap['bgcolor2']?.toString() ??
                      lowerMap['bgcolor1']?.toString() ??
                      '',
                  const Color(0xffEC4899),
                );
                final assetColor = parseColor(
                  lowerMap['assetcolor']?.toString() ??
                      lowerMap['textcolor']?.toString() ??
                      '',
                  Colors.white,
                );
                final indexVal =
                    int.tryParse(lowerMap['index']?.toString() ?? '0') ?? 0;

                newDeals.add({
                  'text': lowerMap['text']?.toString() ?? '',
                  'item': lowerMap['item']?.toString() ?? '',
                  'bgColor1': bgColor1,
                  'bgColor2': bgColor2,
                  'assetcolor': assetColor,
                  'index': indexVal,
                });
              }
            }

            if (raw is List) {
              for (final item in raw) {
                if (item != null) extractDeal(item);
              }
            } else if (raw is Map) {
              for (final entry in raw.values) {
                if (entry != null) extractDeal(entry);
              }
            }

            newDeals.sort(
              (a, b) => (a['index'] as int).compareTo(b['index'] as int),
            );

            if (mounted) {
              setState(() {
                _deals = newDeals;
              });
              _startTimer();
            }
          });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_deals.isEmpty || !_scrollController.hasClients) return;

      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent || (route.animation?.isAnimating ?? false)) {
        return;
      }

      final currentPixels = _scrollController.position.pixels;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final itemWidth = 260.0 + 14.0;

      if (currentPixels >= maxScroll - 10) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.animateTo(
          currentPixels + itemWidth,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _adsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_deals.isEmpty) {
      return const SizedBox(height: 150);
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _deals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final deal = _deals[index];
          return _DealBannerCard(
            text: deal['text'] as String,
            itemCode: deal['item'] as String,
            bgColor1: deal['bgColor1'] as Color,
            bgColor2: deal['bgColor2'] as Color,
            assetColor: deal['assetcolor'] as Color,
          );
        },
      ),
    );
  }
}

class _DealBannerCard extends StatelessWidget {
  const _DealBannerCard({
    required this.text,
    required this.itemCode,
    required this.bgColor1,
    required this.bgColor2,
    required this.assetColor,
  });

  final String text;
  final String itemCode;
  final Color bgColor1;
  final Color bgColor2;
  final Color assetColor;

  Future<Map<String, dynamic>?> _fetchBannerData() async {
    final prodSnap = await FirebaseDatabase.instance.ref('root/products/$itemCode').once();
    if (prodSnap.snapshot.exists && prodSnap.snapshot.value != null) {
      final pm = FirebaseProductModel.fromSnapshot(itemCode, prodSnap.snapshot.value);
      return {'name': pm.name, 'image': pm.picUrl, 'isCategory': false, 'model': pm};
    }
    final catSnap = await FirebaseDatabase.instance.ref('root/category/$itemCode').once();
    if (catSnap.snapshot.exists && catSnap.snapshot.value != null) {
      final map = catSnap.snapshot.value as Map;
      return {'name': map['name'] ?? '', 'image': map['pic'] ?? '', 'isCategory': true};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchBannerData(),
      builder: (context, snapshot) {
        String subtitle = '';
        String? imageUrl;
        bool isCategory = false;
        FirebaseProductModel? productModel;

        if (snapshot.connectionState == ConnectionState.waiting) {
           subtitle = 'Loading...';
        } else if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          subtitle = data['name'] as String;
          imageUrl = data['image'] as String?;
          isCategory = data['isCategory'] as bool;
          productModel = data['model'] as FirebaseProductModel?;
        }

        final cardUI = Container(
          width: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgColor1, bgColor2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "PlusJakartaSans",
                          color: assetColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isNotEmpty ? subtitle : 'Loading...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "PlusJakartaSans",
                          color: assetColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: assetColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: assetColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          isCategory ? 'SHOP NOW' : 'BUY NOW',
                          style: TextStyle(
                            fontFamily: "PlusJakartaSans",
                            color: assetColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(
                    color: assetColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Hero(
                    tag: 'exclusive_$itemCode',
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? OptimizedNetworkImage(
                            imageUrl: imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            placeholder: const SizedBox(),
                            errorWidget: const SizedBox(),
                          )
                        : Icon(Icons.apple_rounded, color: assetColor, size: 34),
                  ),
                ),
              ],
            ),
          ),
        );

        return Container(
          width: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgColor1, bgColor2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              splashColor: assetColor.withOpacity(0.12),
              highlightColor: assetColor.withOpacity(0.06),
              onLongPress: () {
                ShareHelper.shareWidget(Material(color: Colors.transparent, child: cardUI), context: context);
              },
              onTap: () {
                if (isCategory && subtitle.isNotEmpty) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => ItemsPage(initialCategory: subtitle),
                    ),
                  );
                } else if (!isCategory && productModel != null) {
                  final product = Product(
                    name: productModel!.name,
                    weight: productModel!.weight,
                    image: productModel!.picUrl ?? '',
                    price: productModel!.price,
                    oldPrice: productModel!.originalPrice,
                    discount: productModel!.discount,
                    productCode: productModel!.code,
                    unit: productModel!.unit,
                    description: productModel!.details,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(
                        product: product,
                        heroTag: 'exclusive_$itemCode',
                      ),
                    ),
                  );
                }
              },
              child: cardUI.child, // The padding widget
            ),
          ),
        );
      },
    );
  }
}
