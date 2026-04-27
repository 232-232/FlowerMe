import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import 'optimized_network_image.dart';
import '../utils/share_helper.dart';

class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key, this.onBuyNow});

  final VoidCallback? onBuyNow;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late final PageController _pageController;
  Timer? _timer;
  StreamSubscription? _adsSubscription;
  int _currentPage = 0;

  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    if (Firebase.apps.isNotEmpty) {
      _adsSubscription = FirebaseDatabase.instance.ref('root/ads').onValue.listen((
        event,
      ) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          if (mounted) {
            setState(() => _banners = []);
          }
          return;
        }

        final dynamic raw = event.snapshot.value;
        final newBanners = <Map<String, dynamic>>[];

        void extractBanner(dynamic data) {
          if (data is Map<Object?, Object?> || data is Map<String, dynamic>) {
            final Map<dynamic, dynamic> mapData = data as Map<dynamic, dynamic>;
            final bgColorRaw = mapData['bgColor']?.toString() ?? '#EF4444';
            final textColorRaw = mapData['textColor']?.toString() ?? '#FFFFFF';
            final indexVal =
                int.tryParse(mapData['index']?.toString() ?? '0') ?? 0;

            Color bgColor = const Color(0xffEF4444);
            try {
              bgColor = Color(int.parse(bgColorRaw.replaceFirst('#', '0xff')));
            } catch (_) {}

            Color textColor = Colors.white;
            try {
              textColor = Color(
                int.parse(textColorRaw.replaceFirst('#', '0xff')),
              );
            } catch (_) {}

            newBanners.add({
              'text': mapData['text']?.toString() ?? '',
              'imageUrl': mapData['imageUrl']?.toString() ?? '',
              'bgColor': bgColor,
              'textColor': textColor,
              'index': indexVal,
            });
          }
        }

        if (raw is List) {
          for (final item in raw) {
            if (item != null) extractBanner(item);
          }
        } else if (raw is Map) {
          for (final entry in raw.values) {
            if (entry != null) extractBanner(entry);
          }
        }

        newBanners.sort(
          (a, b) => (a['index'] as int).compareTo(b['index'] as int),
        );

        if (mounted) {
          setState(() {
            _banners = newBanners;
          });

          // Precache the first 2 banners — use exact URL to match widget cache key
          try {
            for (int i = 0; i < newBanners.length && i < 2; i++) {
              final url = newBanners[i]['imageUrl'] as String;
              if (url.isNotEmpty) {
                precacheImage(
                  CachedNetworkImageProvider(url, maxWidth: 400),
                  context,
                  onError: (_, __) {},
                );
              }
            }
          } catch (_) {}

          _startTimer();
        }
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_banners.isEmpty || _banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted || !TickerMode.of(context)) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
              // Reset timer on manual swipe to prevent sudden jumps
              _startTimer();
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return _BannerCard(
                text: banner['text'] as String,
                imageUrl: banner['imageUrl'] as String,
                bgColor: banner['bgColor'] as Color,
                textColor: banner['textColor'] as Color,
                onBuyNow: widget.onBuyNow,
              );
            },
          ),
          if (_banners.length > 1)
            Positioned(
              bottom: 12,
              left: 36,
              child: Row(
                children: List.generate(
                  _banners.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _currentPage == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        _currentPage == index ? 0.9 : 0.4,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatefulWidget {
  const _BannerCard({
    required this.text,
    required this.imageUrl,
    required this.bgColor,
    required this.textColor,
    this.onBuyNow,
  });

  final String text;
  final String imageUrl;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onBuyNow;

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with AutomaticKeepAliveClientMixin {
  bool _pressed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cardUI = Container(
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          // Background circle
          Positioned(
            right: -40,
            bottom: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Dynamic Image
          if (widget.imageUrl.isNotEmpty)
            Positioned(
              right: 20,
              top: 20,
              bottom: 20,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: OptimizedNetworkImage(
                    imageUrl: widget.imageUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: const SizedBox(),
                    errorWidget: const SizedBox(),
                  ),
                ),
              ),
            ),
          // Text + button
          Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width * 0.05,
              MediaQuery.sizeOf(context).height * 0.025,
              MediaQuery.sizeOf(context).width * 0.35,
              MediaQuery.sizeOf(context).height * 0.025,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "PlusJakartaSans",
                      color: widget.textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedScale(
                  scale: _pressed ? 0.96 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) {
                      setState(() => _pressed = false);
                      widget.onBuyNow?.call();
                    },
                    onTapCancel: () => setState(() => _pressed = false),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.sizeOf(context).width * 0.05,
                        vertical: MediaQuery.sizeOf(context).height * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        'BUY NOW',
                        style: TextStyle(
                          fontFamily: "PlusJakartaSans",
                          color: AppThemeScope.themeOf(context).primaryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onLongPress: () {
          ShareHelper.shareWidget(
            Material(color: Colors.transparent, child: cardUI),
            context: context,
          );
        },
        child: cardUI,
      ),
    );
  }
}
