import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Offer badge with a subtle scale + glow pulse animation.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.discount});

  final int discount;

  static const double _rotationRad = -0.12;

  @override
  Widget build(BuildContext context) {
    if (discount <= 0) return const SizedBox.shrink();

    return Transform.rotate(
      angle: _rotationRad,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4B3A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4B3A).withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$discount% OFF',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.08, 1.08),
          duration: 900.ms,
          curve: Curves.easeInOut,
        )
        .custom(
          duration: 900.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4B3A)
                        .withValues(alpha: 0.15 + 0.25 * value),
                    blurRadius: 8 + 6 * value,
                    spreadRadius: value * 2,
                  ),
                ],
              ),
              child: child,
            );
          },
        );
  }
}
