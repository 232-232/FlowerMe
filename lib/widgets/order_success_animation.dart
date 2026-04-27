import 'dart:ui';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'order_success_check_painter.dart';

class OrderSuccessAnimation extends StatelessWidget {
  const OrderSuccessAnimation({
    super.key,
    required this.scaleAnimation,
    required this.checkAnimation,
    required this.rippleAnimation,
    required this.confettiController,
    this.glowColor = const Color(0xFF2ECC71),
  });

  final Animation<double> scaleAnimation;
  final Animation<double> checkAnimation;
  final Animation<double> rippleAnimation;
  final ConfettiController confettiController;
  final Color glowColor;

  static const double circleSize = 160;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.07,
                numberOfParticles: 20,
                maxBlastForce: 26,
                minBlastForce: 12,
                gravity: 0.22,
                particleDrag: 0.04,
                shouldLoop: false,
                minimumSize: const Size.square(7),
                maximumSize: const Size(13, 17),
                colors: const [
                  Color(0xFF2ECC71),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFD700),
                  Color(0xFF27AE60),
                  Color(0xFFF1C40F),
                ],
              ),
            ),
          ),
          ...List<Widget>.generate(
            3,
            (index) => _RippleRing(
              animation: rippleAnimation,
              delay: index * 0.16,
              color: glowColor,
            ),
          ),
          AnimatedBuilder(
            animation: scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.45),
                    blurRadius: 32,
                    spreadRadius: 4,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.20),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size.square(80),
                      painter: OrderSuccessCheckPainter(
                        progress: checkAnimation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({
    required this.animation,
    required this.delay,
    required this.color,
  });

  final Animation<double> animation;
  final double delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double progress = ((animation.value - delay) / (1 - delay)).clamp(
          0.0,
          1.0,
        );
        final double opacity = (1 - progress) * 0.40;
        final double scale = lerpDouble(1, 2.4, progress) ?? 1;

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: OrderSuccessAnimation.circleSize,
                height: OrderSuccessAnimation.circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
