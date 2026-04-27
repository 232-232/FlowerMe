import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Hero: left text + BUY NOW, right delivery image.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, this.onBuyNowPressed});

  final VoidCallback? onBuyNowPressed;

  @override
  Widget build(BuildContext context) {
    final appTheme = AppThemeScope.themeOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Instant Free Delivery',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Get fresh\nGrocery',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: onBuyNowPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: appTheme.buyNowButtonBg,
                      borderRadius: BorderRadius.circular(20),
                      // FIX 20: No BoxShadow
                    ),
                    child: const Text(
                      'BUY NOW',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 145, height: 156, child: _HeroImage()),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 10,
          bottom: 14,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: const Color(0xFF6DBF71).withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 24,
          top: 18,
          child: Container(
            width: 58,
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFF2FA14F),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
        Positioned(
          right: 37,
          top: 4,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D9C4B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3C39C),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 25,
          top: 66,
          child: Container(
            width: 14,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3C39C),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          right: 79,
          top: 70,
          child: Transform.rotate(
            angle: -0.28,
            child: Container(
              width: 14,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3C39C),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            width: 110,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFA7632B),
              borderRadius: BorderRadius.circular(14),
              // No BoxShadow
            ),
            child: Stack(
              children: const [
                Positioned(
                  left: 12,
                  top: 10,
                  child: _BasketItem(
                    width: 14,
                    height: 28,
                    color: Color(0xFFE9F0C8),
                  ),
                ),
                Positioned(
                  left: 30,
                  top: 6,
                  child: _BasketItem(
                    width: 16,
                    height: 32,
                    color: Color(0xFFE25D3D),
                  ),
                ),
                Positioned(
                  left: 50,
                  top: 14,
                  child: _BasketItem(
                    width: 12,
                    height: 24,
                    color: Color(0xFFFFE29F),
                  ),
                ),
                Positioned(
                  left: 68,
                  top: 9,
                  child: _BasketItem(
                    width: 14,
                    height: 28,
                    color: Color(0xFFF3F0E5),
                  ),
                ),
                Positioned(
                  left: 87,
                  top: 12,
                  child: _BasketItem(
                    width: 10,
                    height: 24,
                    color: Color(0xFFB8D98E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BasketItem extends StatelessWidget {
  const _BasketItem({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
