import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'widgets/optimized_network_image.dart';

/// Premium add-to-cart animation: product image flies to cart with curved path,
/// then confetti burst and callback (cart bounce, count update).
class AddToCartAnimation {
  AddToCartAnimation._();

  static const int _liftMs = 80;
  static const int _flightMs = 380;
  static const int _confettiDurationMs = 500;

  /// Cubic Bezier: B(t) = (1-t)³P0 + 3(1-t)²t P1 + 3(1-t)t² P2 + t³ P3.
  /// P0 = start, P3 = end; P1 and P2 are control points for an arc.
  static Offset _bezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;
    final t2 = t * t;
    final t3 = t2 * t;
    return Offset(
      mt3 * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t3 * p3.dx,
      mt3 * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t3 * p3.dy,
    );
  }

  /// Runs the full sequence: lift -> curved flight -> onReachedCart.
  /// [tickerProvider] e.g. from TickerProviderStateMixin on the page State.
  static void run({
    required BuildContext context,
    required TickerProvider tickerProvider,
    required Rect imageGlobalRect,
    required Rect cartIconGlobalRect,
    required String productImageUrl,
    required VoidCallback onReachedCart,
  }) {
    final overlay = Overlay.of(context);
    final startCenter = imageGlobalRect.center;
    final endCenter = cartIconGlobalRect.center;

    // Control points for arc: tighter curve for snappier feel
    final dx = endCenter.dx - startCenter.dx;
    final p1 = Offset(
      startCenter.dx + dx * 0.35,
      startCenter.dy - 28,
    );
    final p2 = Offset(
      endCenter.dx - dx * 0.35,
      endCenter.dy + 12,
    );

    late OverlayEntry entry;
    late AnimationController liftController;
    late AnimationController flightController;
    late Animation<double> liftScale;
    late Animation<double> flightT;
    late Animation<double> flightScale;
    late Animation<double> flightRotation;

    void removeOverlay() {
      try {
        liftController.dispose();
        flightController.dispose();
        entry.remove();
      } catch (_) {}
    }

    liftController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: _liftMs),
    );
    liftScale = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: liftController, curve: Curves.easeOut),
    );

    flightController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: _flightMs),
    );
    flightT = CurvedAnimation(
      parent: flightController,
      curve: Curves.easeInOutCubic,
    );
    flightScale = Tween<double>(begin: 1.08, end: 0.35).animate(flightT);
    flightRotation = Tween<double>(begin: 0, end: 0.08).animate(flightT);

    final imageSize = Size(
      imageGlobalRect.width.clamp(48.0, 90.0),
      imageGlobalRect.height.clamp(48.0, 90.0),
    );

    entry = OverlayEntry(
      builder: (ctx) => IgnorePointer(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([liftController, flightController]),
              builder: (context, _) {
                double scale = liftScale.value;
                double t = 0;
                Offset position = startCenter;
                double rotation = 0;

                if (flightController.isAnimating) {
                  t = flightT.value;
                  position = _bezier(
                    startCenter,
                    p1,
                    p2,
                    endCenter,
                    t,
                  );
                  scale = flightScale.value;
                  rotation = flightRotation.value;
                } else if (liftController.isAnimating) {
                  position = startCenter;
                }

                return Positioned(
                  left: position.dx - imageSize.width * scale / 2,
                  top: position.dy - imageSize.height * scale / 2,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: imageSize.width,
                        height: imageSize.height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: OptimizedNetworkImage(
                            imageUrl: productImageUrl,
                            width: imageSize.width,
                            height: imageSize.height,
                            fit: BoxFit.cover,
                            placeholder: const _ImagePlaceholder(),
                            errorWidget: const _ImagePlaceholder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);

    liftController.forward().then((_) {
      flightController.forward().then((_) {
        removeOverlay();
        // Only run cart callback if the view is still active (avoids disposed EngineFlutterView on web).
        if (context.mounted) {
          onReachedCart();
        }
      });
    });
  }

  /// Shows confetti burst from [globalPosition] for [durationMs], then removes overlay.
  static void showConfettiAt({
    required BuildContext context,
    required Offset globalPosition,
    int durationMs = _confettiDurationMs,
  }) {
    final overlay = Overlay.of(context);
    final controller = ConfettiController(
      duration: Duration(milliseconds: durationMs),
    );

    late OverlayEntry confettiEntry;
    confettiEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: globalPosition.dx - 60,
        top: globalPosition.dy - 60,
        width: 120,
        height: 120,
        child: IgnorePointer(
          child: ConfettiWidget(
            confettiController: controller,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.06,
            numberOfParticles: 14,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.28,
            particleDrag: 0.06,
            shouldLoop: false,
            minimumSize: const Size.square(6),
            maximumSize: const Size(12, 14),
            colors: const [
              Color(0xFF63C44A), // green
              Color(0xFFFFD54F), // yellow
              Color(0xFFFFA726), // orange
              Color(0xFF42A5F5), // blue
              Color(0xFFEC407A), // pink
            ],
          ),
        ),
      ),
    );

    overlay.insert(confettiEntry);
    controller.play();

    Future.delayed(Duration(milliseconds: durationMs + 50), () {
      if (!context.mounted) return;
      try {
        controller.dispose();
        confettiEntry.remove();
      } catch (_) {}
    });
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F6),
      alignment: Alignment.center,
      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFBDBDBD), size: 28),
    );
  }
}
