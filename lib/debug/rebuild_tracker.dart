import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dc_log.dart';

/// Opt-in mixin for [State] subclasses that logs every rebuild in debug mode.
///
/// Usage (add `with RebuildTracker` to any State):
/// ```dart
/// class _HomePageState extends State<HomePage> with RebuildTracker { … }
/// ```
///
/// Console output:
/// ```
/// [RebuildTracker] _HomePageState rebuild #3  ┄ 13:01:45.321
/// ```
///
/// Zero overhead in release mode — the entire body is inside [kDebugMode].
mixin RebuildTracker<T extends StatefulWidget> on State<T> {
  int _rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      _rebuildCount++;
      dcLog('Rebuild', '${runtimeType} #$_rebuildCount');
    }
    return buildTracked(context);
  }

  /// Override this instead of [build] when using [RebuildTracker].
  Widget buildTracked(BuildContext context);
}
