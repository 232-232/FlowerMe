import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/feed_product_model.dart';
import '../models/product.dart' as app_models;
import '../pages/product_details_page.dart';
import '../providers/home_feed_provider.dart';
import '../theme/app_colors.dart';

/// Auto-scrolling marquee ticker for quick categories like
/// Oil • Bread • Eggs • Milk • Salt.
class SuggestionBox extends StatefulWidget {
  const SuggestionBox({super.key});

  @override
  State<SuggestionBox> createState() => _SuggestionBoxState();
}

class _SuggestionBoxState extends State<SuggestionBox> {
  static const List<String> _defaultItems = [
    'Oil',
    'Bread',
    'Eggs',
    'Milk',
    'Salt',
  ];

  late final ScrollController _controller;
  Timer? _timer;

  static const double _scrollStep = 0.5; // Slightly slower for better readability
  static const Duration _tick = Duration(milliseconds: 32); // Lower frequency to save CPU cycles

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      // Stop doing any work while this widget is covered by another route or while
      // another route is animating its exit.
      if (!mounted || !TickerMode.of(context)) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (!_controller.hasClients || !_controller.position.hasContentDimensions) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      
      final offset = _controller.offset;
      if (offset >= max) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo((offset + _scrollStep).clamp(0.0, max));
      }
    });
  }

  void _pause() => _timer?.cancel();

  void _resume() => _startAutoScroll();

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeFeed = context.watch<HomeFeedProvider>();
    final theme = AppThemeScope.themeOf(context);
    final isDefault = homeFeed.suggestionBoxItems.isEmpty;
    final items = isDefault ? _defaultItems : homeFeed.suggestionBoxItems;

    return SizedBox(
      height: 40,
      child: Listener(
        onPointerDown: (_) => _pause(),
        onPointerUp: (_) => _resume(),
        onPointerCancel: (_) => _resume(),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemBuilder: (context, index) {
            final dynamicItem = items[index % items.length];

            String labelText;
            FeedProductModel? feedModel;

            if (isDefault) {
              labelText = dynamicItem as String;
            } else {
              feedModel = dynamicItem as FeedProductModel;
              labelText =
                  (feedModel.labelName != null &&
                      feedModel.labelName!.isNotEmpty)
                  ? feedModel.labelName!
                  : feedModel.name;
            }

            return GestureDetector(
              onTap: () {
                if (isDefault || feedModel == null) return;

                final product = app_models.Product(
                  name: feedModel.name,
                  weight: feedModel.label,
                  image: feedModel.picUrl,
                  price: feedModel.offerPrice,
                  oldPrice: feedModel.mrp,
                  discount: feedModel.discountPercent,
                  productCode: feedModel.productCode,
                  unit: feedModel.unit,
                );

                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailsPage(product: product),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labelText,
                    style: TextStyle(
                      fontFamily: "PlusJakartaSans",
                      color: const Color.fromARGB(181, 32, 32, 33),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: items.isEmpty ? 0 : items.length * 20,
        ),
      ),
    );
  }
}
