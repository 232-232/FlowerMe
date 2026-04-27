import 'package:flutter/widgets.dart';
import 'screen_size.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppSpacing — responsive padding / gap token system
// ─────────────────────────────────────────────────────────────────────────────
//
// Call AppSpacing.of(context) to get a [_Spacing] instance whose values
// automatically adapt to the current screen size.
//
// Example:
//   final s = AppSpacing.of(context);
//   Padding(padding: EdgeInsets.all(s.cardPadding), …)
//
class AppSpacing {
  const AppSpacing._({
    required this.screenPadding,
    required this.cardPadding,
    required this.cardInnerPadding,
    required this.gridSpacing,
    required this.sectionGap,
    required this.tileSize,
  });

  /// Horizontal screen edge padding.
  final double screenPadding;

  /// Outer card margin / container padding.
  final double cardPadding;

  /// Inner card content padding.
  final double cardInnerPadding;

  /// GridView cross-axis & main-axis spacing.
  final double gridSpacing;

  /// Vertical gap between major sections.
  final double sectionGap;

  /// Size of a category tile image box.
  final double tileSize;

  // ── Precomputed instances ─────────────────────────────────────────────────

  static const AppSpacing _small = AppSpacing._(
    screenPadding:    12,
    cardPadding:      6,
    cardInnerPadding: 5,
    gridSpacing:      6,
    sectionGap:       10,
    tileSize:         58,
  );

  static const AppSpacing _medium = AppSpacing._(
    screenPadding:    16,
    cardPadding:      8,
    cardInnerPadding: 6,
    gridSpacing:      8,
    sectionGap:       14,
    tileSize:         68,
  );

  static const AppSpacing _large = AppSpacing._(
    screenPadding:    20,
    cardPadding:      12,
    cardInnerPadding: 10,
    gridSpacing:      12,
    sectionGap:       20,
    tileSize:         80,
  );

  /// Returns the correct [AppSpacing] instance for [context]'s screen size.
  static AppSpacing of(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }

  /// Returns the correct [AppSpacing] instance from an explicit [ScreenSize].
  static AppSpacing forSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextScale — responsive font-size token system
// ─────────────────────────────────────────────────────────────────────────────

class AppTextScale {
  const AppTextScale._({
    required this.label,
    required this.body,
    required this.subtitle,
    required this.title,
    required this.price,
    required this.overline,
  });

  /// Tiny label (weight, category name).
  final double label;

  /// Default body text (product name line 1).
  final double body;

  /// Subtitle / helper text.
  final double subtitle;

  /// Section title / large heading.
  final double title;

  /// Price display.
  final double price;

  /// Overline / metadata.
  final double overline;

  // ── Precomputed instances ─────────────────────────────────────────────────

  static const AppTextScale _small = AppTextScale._(
    label:    10,
    body:     12,
    subtitle: 11,
    title:    14,
    price:    13,
    overline: 9,
  );

  static const AppTextScale _medium = AppTextScale._(
    label:    11,
    body:     13,
    subtitle: 12,
    title:    16,
    price:    15,
    overline: 10,
  );

  static const AppTextScale _large = AppTextScale._(
    label:    12,
    body:     14,
    subtitle: 13,
    title:    18,
    price:    17,
    overline: 11,
  );

  /// Returns the correct [AppTextScale] for [context]'s screen size.
  static AppTextScale of(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }

  /// Returns the correct [AppTextScale] from an explicit [ScreenSize].
  static AppTextScale forSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppGridConfig — responsive grid column / aspect-ratio config
// ─────────────────────────────────────────────────────────────────────────────

class AppGridConfig {
  const AppGridConfig._({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.maxCrossAxisExtent,
  });

  /// Number of columns in the product grid.
  final int crossAxisCount;

  /// Product card height : width ratio.
  final double childAspectRatio;

  /// Max tile width for category grid (SliverGridDelegateWithMaxCrossAxisExtent).
  final double maxCrossAxisExtent;

  static const AppGridConfig _small = AppGridConfig._(
    crossAxisCount:   2,
    childAspectRatio: 0.68,
    maxCrossAxisExtent: 100,
  );

  static const AppGridConfig _medium = AppGridConfig._(
    crossAxisCount:   2,
    childAspectRatio: 0.78,
    maxCrossAxisExtent: 120,
  );

  static const AppGridConfig _large = AppGridConfig._(
    crossAxisCount:   3,
    childAspectRatio: 0.82,
    maxCrossAxisExtent: 130,
  );

  static AppGridConfig of(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }

  static AppGridConfig forSize(ScreenSize size) {
    switch (size) {
      case ScreenSize.small:  return _small;
      case ScreenSize.medium: return _medium;
      case ScreenSize.large:  return _large;
      default:                return _medium;
    }
  }
}
