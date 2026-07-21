import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular crowd level meter (0–10) with arc progress and word label.
class CrowdMeter extends StatelessWidget {
  const CrowdMeter({
    super.key,
    required this.level,
    this.size = 60,
  });

  final int level;
  final double size;

  static int clampLevel(int raw) => raw.clamp(0, 10);

  static String wordLabel(int raw) {
    final value = clampLevel(raw);
    if (value == 0) return 'Empty';
    if (value <= 2) return 'Quiet';
    if (value <= 4) return 'Moderate';
    if (value <= 6) return 'Busy';
    if (value <= 8) return 'Crowded';
    return 'Packed';
  }

  static Color levelColor(int raw) {
    final value = clampLevel(raw);
    if (value <= 4) return const Color(0xFF4CAF50);
    if (value <= 6) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  @override
  Widget build(BuildContext context) {
    final value = clampLevel(level);
    final color = levelColor(value);
    final label = wordLabel(value);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _CrowdMeterPainter(
              progress: value / 10,
              fillColor: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.13,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrowdMeterPainter extends CustomPainter {
  _CrowdMeterPainter({
    required this.progress,
    required this.fillColor,
  });

  final double progress;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, startAngle, fullSweep, false, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        startAngle,
        fullSweep * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrowdMeterPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor;
  }
}
