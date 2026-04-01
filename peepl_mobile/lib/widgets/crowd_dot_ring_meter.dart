import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Peepl-style crowd meter: 10 dots in a ring; [level] filled dots (0–10).
/// Status label centered; dot colors follow crowd band (empty/light / moderate / busy/packed).
class CrowdDotRingMeter extends StatelessWidget {
  const CrowdDotRingMeter({
    super.key,
    required this.level,
    this.size = 76,
  });

  final int level;
  final double size;

  static int clampLevel(int raw) => raw.clamp(0, 10);

  static String statusWord(int l) {
    final v = clampLevel(l);
    if (v <= 2) return 'EMPTY';
    if (v <= 4) return 'LIGHT';
    if (v <= 6) return 'MODERATE';
    if (v <= 8) return 'BUSY';
    return 'PACKED';
  }

  /// Filled-dot color: red busy/packed, blue moderate, white/grey light/empty.
  static Color filledDotColor(int l) {
    final v = clampLevel(l);
    if (v <= 4) return const Color(0xFFE0E0E0);
    if (v <= 6) return const Color(0xFF42A5F5);
    return const Color(0xFFE53935);
  }

  static Color emptyDotColor() => Colors.white.withValues(alpha: 0.28);

  @override
  Widget build(BuildContext context) {
    final l = clampLevel(level);
    final label = statusWord(l);
    final fill = filledDotColor(l);
    final empty = emptyDotColor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DotRingPainter(
              filledCount: l,
              filledColor: fill,
              emptyColor: empty,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.05,
              shadows: [
                Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotRingPainter extends CustomPainter {
  _DotRingPainter({
    required this.filledCount,
    required this.filledColor,
    required this.emptyColor,
  });

  final int filledCount;
  final Color filledColor;
  final Color emptyColor;

  static const int _totalDots = 10;
  static const double _dotRadius = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringR = math.min(size.width, size.height) / 2 - _dotRadius - 3;

    for (var i = 0; i < _totalDots; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / _totalDots);
      final cx = center.dx + ringR * math.cos(angle);
      final cy = center.dy + ringR * math.sin(angle);
      final paint = Paint()
        ..color = i < filledCount ? filledColor : emptyColor
        ..isAntiAlias = true;
      canvas.drawCircle(Offset(cx, cy), _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotRingPainter oldDelegate) {
    return oldDelegate.filledCount != filledCount ||
        oldDelegate.filledColor != filledColor ||
        oldDelegate.emptyColor != emptyColor;
  }
}
