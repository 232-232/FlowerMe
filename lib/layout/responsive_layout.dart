// Barrel export — import this single file to access the full responsive system.
//
// Usage:
//   import 'package:dailyclub_main/layout/responsive_layout.dart';
//
// Available symbols:
//   ScreenSize, AppBreakpoints, ScreenSizeFactory, ScreenSizeContext,
//   AppSpacing, AppTextScale, AppGridConfig,
//   ResponsiveWrapper, ResponsiveBuilder, ScreenSizeBuilder,
//   ResponsiveLayout (the legacy max-width container, kept for compatibility)

export 'screen_size.dart';
export 'responsive_config.dart';
export 'responsive_wrapper.dart';

// ─── Legacy max-width container (kept for backward compatibility) ─────────────
import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 800.0, // Swiggy/Zepto-style web container
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
