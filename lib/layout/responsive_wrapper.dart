import 'package:flutter/widgets.dart';
import 'screen_size.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResponsiveWrapper
// ─────────────────────────────────────────────────────────────────────────────
//
// Drop-in wrapper that selects one of three child builders based on the
// available width from [LayoutBuilder]. This means it reacts to the *actual*
// constrained width of its parent, not the device screen width, making it safe
// to use inside columns, drawers, and side-by-side panes.
//
// Usage:
//   ResponsiveWrapper(
//     small:  (ctx, constraints) => SmallProductGrid(products: p),
//     medium: (ctx, constraints) => MediumProductGrid(products: p),
//     large:  (ctx, constraints) => LargeProductGrid(products: p),
//   )
//
// If only [medium] is provided the other two fall back to it (opt-in overrides).
//

typedef ResponsiveBuilder = Widget Function(BuildContext context, BoxConstraints constraints);

class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({
    super.key,
    required this.medium,
    ResponsiveBuilder? small,
    ResponsiveBuilder? large,
  })  : _small = small,
        _large = large;

  /// Builder invoked on screens narrower than [AppBreakpoints.small] (< 360 dp).
  final ResponsiveBuilder? _small;

  /// Builder invoked on standard-width screens (360 dp – 599 dp).
  final ResponsiveBuilder medium;

  /// Builder invoked on wide screens (≥ 600 dp).
  final ResponsiveBuilder? _large;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final size = ScreenSizeX.fromWidth(width);

        switch (size) {
          case ScreenSize.small:
            return (_small ?? medium)(ctx, constraints);
          case ScreenSize.medium:
            return medium(ctx, constraints);
          case ScreenSize.large:
            return (_large ?? medium)(ctx, constraints);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScreenSizeBuilder
// ─────────────────────────────────────────────────────────────────────────────
//
// Lightweight variant that just exposes [ScreenSize] to the builder without
// forcing you to provide all three alternatives.
//
// Usage:
//   ScreenSizeBuilder(
//     builder: (ctx, size) => Text('Cols: ${size.pick(small:2, medium:2, large:3)}'),
//   )
//

class ScreenSizeBuilder extends StatelessWidget {
  const ScreenSizeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = ScreenSizeX.fromWidth(constraints.maxWidth);
        return builder(ctx, size);
      },
    );
  }
}
