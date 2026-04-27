import 'package:flutter/material.dart';

/// A custom page route that uses a lightweight slide + fade transition
/// instead of the heavier default MaterialPageRoute.
///
/// Key differences vs MaterialPageRoute:
/// - Shorter duration (280 ms vs 350 ms) — feels snappier
/// - Uses [Curves.easeOutCubic] — smooth deceleration
/// - The exiting page fades slightly rather than doing an expensive full repaint
/// - Both pages are composited as GPU layers during the transition, so the
///   CPU does almost no work once the transition starts.
class SmoothSlideRoute<T> extends PageRouteBuilder<T> {
  SmoothSlideRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide the incoming page in from the right
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

            // Fade the outgoing page slightly (much cheaper than sliding it)
            final fadeOut = Tween<double>(begin: 1.0, end: 0.97).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: fadeOut,
              child: SlideTransition(position: slideIn, child: child),
            );
          },
        );
}
