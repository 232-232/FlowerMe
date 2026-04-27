import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Perf {
  static bool enabled = false;
  static final Map<String, Stopwatch> _timers = {};

  /// Start a timer for a specific section and key. Starts only once to avoid rebuild issues.
  static void start(String section, String key) {
    if (!enabled) return;
    final fullKey = '${section}_$key';
    if (_timers.containsKey(fullKey)) return; // Prevents restarting timer unintentionally
    
    _timers[fullKey] = Stopwatch()..start();
    // debugPrint('[$section] Fetch start: $key');
  }

  /// End the timer and log the duration. Triggers warnings if slow.
  static void end(String section, String key, {String? extra}) {
    final ms = stopAndGetMs(section, key);
    if (ms == null) return;

    final ext = extra != null ? ' $extra' : '';

    if (section == 'Firebase' && ms > 500) {
      // debugPrint('[WARNING] [$section] Fetch end: $key in $ms ms (SLOW FETCH)$ext');
    } else {
      // debugPrint('[$section] Fetch end: $key in $ms ms$ext');
    }
  }

  /// Stop the timer and return the elapsed milliseconds without logging automatically.
  static int? stopAndGetMs(String section, String key) {
    if (!enabled) return null;
    final fullKey = '${section}_$key';
    if (!_timers.containsKey(fullKey)) return null;

    final ms = _timers[fullKey]!.elapsedMilliseconds;
    _timers.remove(fullKey);
    return ms;
  }

  /// Single-event logs (e.g., App lifecycle, Image load times without dual start/end in separate places)
  static void log(String section, String message, {bool warning = false}) {
    if (!enabled) return;
    final prefix = warning ? '[WARNING] ' : '';
    // debugPrint('$prefix[$section] $message');
  }

  /// Specifically logs an image load with the tag and duration. Gives a warning if above 300ms.
  static void logImageLoad(String tag, int ms, String urlOrName) {
    if (!enabled) return;
    if (ms > 300) {
      // debugPrint('[WARNING] [$tag] Image loaded in $ms ms: $urlOrName');
    } else {
      // debugPrint('[$tag] Image loaded in $ms ms: $urlOrName');
    }
  }
}
