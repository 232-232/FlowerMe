import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoint thresholds (dp / logical pixels)
// ─────────────────────────────────────────────────────────────────────────────
//
//  small  : width  < 360   (very compact phones — e.g. 320 px)
//  medium : 360 ≤  width < 600   (standard phones)
//  large  : width ≥ 600   (large phones, tablets, web)
//
abstract final class AppBreakpoints {
  static const double small = 360.0;
  static const double large = 600.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// ScreenSize enum
// ─────────────────────────────────────────────────────────────────────────────

enum ScreenSize { small, medium, large }

extension ScreenSizeX on ScreenSize {
  bool get isSmall  => this == ScreenSize.small;
  bool get isMedium => this == ScreenSize.medium;
  bool get isLarge  => this == ScreenSize.large;

  /// Pick a value based on current screen size.
  ///
  /// Example:
  ///   final cols = size.pick(small: 2, medium: 2, large: 3);
  T pick<T>({required T small, required T medium, required T large}) {
    switch (this) {
      case ScreenSize.small:  return small;
      case ScreenSize.medium: return medium;
      case ScreenSize.large:  return large;
      // Safety fallback: dart2js must never generate an implicit undefined
      // return from this switch. Medium is the most conservative default.
      default: return medium;
    }
  }

  // ── Static factory ────────────────────────────────────────────────────────

  /// Derives [ScreenSize] from a raw pixel [width].
  static ScreenSize fromWidth(double width) {
    if (width < AppBreakpoints.small) return ScreenSize.small;
    if (width < AppBreakpoints.large) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// Derives [ScreenSize] from the nearest [MediaQuery] ancestor.
  static ScreenSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BuildContext extension
// ─────────────────────────────────────────────────────────────────────────────

extension ScreenSizeContext on BuildContext {
  /// Returns the [ScreenSize] from this context's [MediaQuery].
  ///
  /// Prefer using [ScreenSizeX.fromWidth] when you already have constraints
  /// from a [LayoutBuilder] so the breakpoint reacts to available width rather
  /// than the full device width.
  ScreenSize get screenSize => ScreenSizeX.fromWidth(MediaQuery.sizeOf(this).width);
}
