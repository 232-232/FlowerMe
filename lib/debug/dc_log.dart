import 'package:flutter/foundation.dart';

/// Timestamped debug logger — only active in debug builds.
///
/// Usage:
/// ```dart
/// dcLog('Cart', 'Item added: ${product.name}');
/// // output: [13:01:45.123][Cart] Item added: Turmeric Powder
/// ```
void dcLog(String tag, String msg) {
  if (!kDebugMode) return;
  // Removed to clear debug console prints as requested
  // final ts = DateTime.now().toIso8601String().substring(11, 23);
  // debugPrint('[$ts][$tag] $msg');
}
