import 'dart:math' as math;

import 'package:flutter/material.dart';

class CrowdMeter extends StatelessWidget {
  final int level; // 0-10
  final double size; // outer diameter
  final double strokeRatio;
  final double fontScale;
  const CrowdMeter({
    super.key,
    required this.level,
    this.size = 52,
    this.strokeRatio = 0.13,
    this.fontScale = 0.44,
  });

  Color get _color => levelColor(level);

  static Color levelColor(int level) {
    final clamped = level.clamp(0, 10);
    if (clamped <= 4) return const Color(0xFF4CAF50);
    if (clamped <= 7) return const Color(0xFFFFA726);
    return const Color(0xFFFF5722);
  }

  static String wordLabel(int level) {
    final value = level.clamp(0, 10);
    if (value == 0) return 'Empty';
    if (value <= 2) return 'Quiet';
    if (value <= 4) return 'Moderate';
    if (value <= 6) return 'Busy';
    if (value <= 8) return 'Crowded';
    return 'Packed';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: (level.clamp(0, 10)) / 10.0,
          color: _color,
          stroke: size * strokeRatio,
        ),
        child: Center(
          child: Text(
            '$level',
            style: TextStyle(
              color: _color,
              fontSize: size * fontScale,
              fontWeight: FontWeight.w900,
              height: 1.0,
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double stroke;
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // faint track so the ring reads on any photo
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}
