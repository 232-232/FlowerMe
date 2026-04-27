import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../pages/order_tracking_page.dart';

/// Draggable floating action button that opens the order tracking page.
/// Shared between HomePage and ItemsPage to avoid duplication.
class DraggableTrackOrderFab extends StatefulWidget {
  const DraggableTrackOrderFab({super.key, required this.orderId, required this.activeCount});

  final String orderId;
  final int activeCount;

  @override
  State<DraggableTrackOrderFab> createState() => _DraggableTrackOrderFabState();
}

class _DraggableTrackOrderFabState extends State<DraggableTrackOrderFab> {
  Alignment _alignment = const Alignment(0.9, 0.7);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: _alignment,
          child: GestureDetector(
            onPanUpdate: (details) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              if (width == 0 || height == 0) return;
              setState(() {
                final dx = details.delta.dx / (width / 2);
                final dy = details.delta.dy / (height / 2);
                _alignment = Alignment(
                  (_alignment.x + dx).clamp(-1.0, 1.0),
                  (_alignment.y + dy).clamp(-1.0, 1.0),
                );
              });
            },
            child: _TrackOrderFab(orderId: widget.orderId, activeCount: widget.activeCount),
          ),
        );
      },
    );
  }
}

class _TrackOrderFab extends StatelessWidget {
  const _TrackOrderFab({required this.orderId, required this.activeCount});

  final String orderId;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeScope.themeOf(context).primaryAccent;
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderTrackingPage(initialOrderId: orderId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                activeCount > 1 ? 'Track $activeCount orders' : 'Track order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
