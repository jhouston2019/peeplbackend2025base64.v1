import 'package:flutter/material.dart';

/// Premium navy palette for the venue detail dashboard.
class PeeplDetailTokens {
  PeeplDetailTokens._();

  static const background = Color(0xFF08182F);
  static const card = Color(0xFF102748);
  static const cardElevated = Color(0xFF17345C);
  static const accentBlue = Color(0xFF2E6CFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC9D3E6);
  static const border = Color(0x14FFFFFF);

  static const cardRadius = 16.0;
  static const heroRadius = 24.0;

  static const cardShadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 4),
    blurRadius: 16,
    spreadRadius: 0,
  );

  static const glassFill = Color(0x33FFFFFF);
  static const glassBorder = Color(0x1FFFFFFF);

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
      );
}
