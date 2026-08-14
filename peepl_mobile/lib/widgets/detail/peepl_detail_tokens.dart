import 'package:flutter/material.dart';

import '../home/peepl_home_tokens.dart';

/// Light glass-shell tokens for the venue detail screen — aligned with [PeeplHomeTokens].
class PeeplDetailTokens {
  PeeplDetailTokens._();

  static const background = Colors.transparent;
  static const card = PeeplHomeTokens.chipSurface;
  static const cardElevated = PeeplHomeTokens.chipSurface;
  static const accentBlue = PeeplHomeTokens.brandBlue;
  static const actionGreen = PeeplHomeTokens.actionGreen;
  static const textPrimary = PeeplHomeTokens.headerForeground;
  static const textSecondary = PeeplHomeTokens.headerMuted;
  static const textTertiary = Color(0xFF8A9BAA);
  static const border = PeeplHomeTokens.chipBorderLight;
  static const glassFill = Color(0xCCFFFFFF);
  static const glassBorder = Color(0x66FFFFFF);
  static const glassIconForeground = PeeplHomeTokens.headerForeground;

  static const cardRadius = 16.0;
  static const heroRadius = 0.0;

  static const cardShadow = BoxShadow(
    color: Color(0x120D2340),
    offset: Offset(0, 4),
    blurRadius: 16,
    spreadRadius: 0,
  );

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
        boxShadow: const [cardShadow],
      );

  static BoxDecoration glassDecoration({double radius = 20}) => BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      );

  /// Responsive hero height (~300–360px).
  static double heroHeightFor(BuildContext context) {
    return (MediaQuery.sizeOf(context).height * 0.38).clamp(300.0, 360.0);
  }
}
