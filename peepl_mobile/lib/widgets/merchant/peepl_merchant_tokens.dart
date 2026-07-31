import 'dart:ui';

import 'package:flutter/material.dart';

/// Premium navy palette for the Peepl Merchant Center.
class PeeplMerchantTokens {
  PeeplMerchantTokens._();

  static const background = Color(0xFF081A2F);
  static const shellNavy = Color(0xFF0D2340);
  static const card = Color(0xFF102748);
  static const cardElevated = Color(0xFF17345C);
  static const accentBlue = Color(0xFF2E6CFF);
  static const accentBlueSoft = Color(0x662E6CFF);
  static const accentGradientStart = Color(0xFF2E6CFF);
  static const accentGradientEnd = Color(0xFF1B4FD8);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC9D3E6);
  static const textMuted = Color(0x99C9D3E6);
  static const border = Color(0x14FFFFFF);
  static const glassFill = Color(0x33FFFFFF);
  static const glassBorder = Color(0x1FFFFFFF);
  static const success = Color(0xFF66E38D);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFFF6B6B);
  static const liveRed = Color(0xFFFF4757);

  static const liveGreen = Color(0xFF66E38D);

  static const cardRadius = 24.0;
  static const chipRadius = 14.0;
  static const buttonRadius = 16.0;

  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const iconXl = 32.0;

  static const pagePadding = 20.0;
  static const sectionGap = 28.0;
  static const cardGap = 14.0;

  static const cardShadow = BoxShadow(
    color: Color(0x50000000),
    offset: Offset(0, 8),
    blurRadius: 24,
    spreadRadius: -4,
  );

  static const glowShadow = BoxShadow(
    color: Color(0x402E6CFF),
    offset: Offset(0, 4),
    blurRadius: 20,
    spreadRadius: 0,
  );

  static const premiumShadow = [
    cardShadow,
    glowShadow,
  ];

  static BoxDecoration cardDecoration({Color? color, bool glow = false}) =>
      BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
        boxShadow: glow ? premiumShadow : const [cardShadow],
      );

  static BoxDecoration glassDecoration({double radius = cardRadius}) =>
      BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder),
      );

  static BoxDecoration gradientCardDecoration() => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardElevated, card],
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
        boxShadow: premiumShadow,
      );

  static BoxDecoration heroGradient() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D2340),
            Color(0xFF081A2F),
            Color(0xFF102748),
            Color(0xFF17345C),
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ),
      );

  static BoxDecoration glassHeroOverlay() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glassFill.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      );

  static TextStyle heroGreeting(BuildContext context) => TextStyle(
        fontSize: 15 * MediaQuery.textScalerOf(context).scale(1),
        color: textSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      );

  static TextStyle heroTitle(BuildContext context) => TextStyle(
        fontSize: 28 * MediaQuery.textScalerOf(context).scale(1),
        color: textPrimary,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 20 * MediaQuery.textScalerOf(context).scale(1),
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle metricValue(BuildContext context) => TextStyle(
        fontSize: 26 * MediaQuery.textScalerOf(context).scale(1),
        color: textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle metricLabel(BuildContext context) => TextStyle(
        fontSize: 12 * MediaQuery.textScalerOf(context).scale(1),
        color: textSecondary,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  static TextStyle cardTitle(BuildContext context) => TextStyle(
        fontSize: 18 * MediaQuery.textScalerOf(context).scale(1),
        color: textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.2,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontSize: 14 * MediaQuery.textScalerOf(context).scale(1),
        color: textSecondary,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 12 * MediaQuery.textScalerOf(context).scale(1),
        color: textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static Widget blurredBackdrop({required Widget child, double sigma = 12}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
