import 'dart:ui';

import 'package:flutter/material.dart';

class OrderSuccessCheckPainter extends CustomPainter {
  const OrderSuccessCheckPainter({
    required this.progress,
    this.color = Colors.white,
    this.strokeWidth = 10,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final Path checkPath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.54)
      ..lineTo(size.width * 0.43, size.height * 0.74)
      ..lineTo(size.width * 0.80, size.height * 0.33);

    final double clampedProgress = progress.clamp(0.0, 1.0);

    for (final PathMetric metric in checkPath.computeMetrics()) {
      final Path visiblePath = metric.extractPath(
        0,
        metric.length * clampedProgress,
      );
      canvas.drawPath(visiblePath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrderSuccessCheckPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
