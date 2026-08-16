import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home/peepl_home_tokens.dart';

class CrowdMeter extends StatelessWidget {
  final int level; // 0-10
  final double size; // outer diameter
  final double strokeRatio;
  final double fontScale;
  final double trackAlpha;
  const CrowdMeter({
    super.key,
    required this.level,
    this.size = 52,
    this.strokeRatio = 0.13,
    this.fontScale = 0.44,
    this.trackAlpha = 0.28,
  });

  Color get _color => levelColor(level);

  static Color levelColor(int level) {
    final clamped = level.clamp(0, 10);
    if (clamped <= 0) return const Color(0xFF9E9E9E);
    if (clamped <= 4) return PeeplHomeTokens.crowdLight;
    if (clamped <= 7) return PeeplHomeTokens.crowdMedium;
    return PeeplHomeTokens.crowdHigh;
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
          trackAlpha: trackAlpha,
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
                  offset: Offset.zero,
                  blurRadius: 6,
                  color: Color(0x99000000),
                ),
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Color(0xE6000000),
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
  final double trackAlpha;
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
    required this.trackAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // faint track so the ring reads on any photo
    final track = Paint()
      ..color = Colors.white.withValues(alpha: trackAlpha)
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
      old.progress != progress ||
      old.color != color ||
      old.stroke != stroke ||
      old.trackAlpha != trackAlpha;
}
