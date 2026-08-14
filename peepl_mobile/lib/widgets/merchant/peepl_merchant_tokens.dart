import 'dart:ui';

import 'package:flutter/material.dart';

import '../home/peepl_home_tokens.dart';

/// Light-shell palette for the Peepl Merchant Center (aligned with home feed).
class PeeplMerchantTokens {
  PeeplMerchantTokens._();

  static const background = PeeplHomeTokens.feedBackground;
  static const shellNavy = PeeplHomeTokens.shellNavy;
  static const card = Color(0xD9FFFFFF);
  static const cardElevated = Color(0xEEFFFFFF);
  static const accentBlue = PeeplHomeTokens.brandBlue;
  static const accentBlueSoft = Color(0x331685FF);
  static const accentGradientStart = Color(0xFF1685FF);
  static const accentGradientEnd = Color(0xFF0096FF);
  static const textPrimary = PeeplHomeTokens.headerForeground;
  static const textSecondary = PeeplHomeTokens.headerMuted;
  static const textMuted = Color(0x995A6B7A);
  static const border = PeeplHomeTokens.chipBorderLight;
  static const glassFill = PeeplHomeTokens.chipSurface;
  static const glassBorder = PeeplHomeTokens.chipBorderLight;
  static const success = Color(0xFF48EF72);
  static const warning = PeeplHomeTokens.dealsYellow;
  static const danger = Color(0xFFFF6474);
  static const liveRed = Color(0xFFFF6474);
  static const liveGreen = Color(0xFF48EF72);

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
    color: Color(0x14000000),
    offset: Offset(0, 4),
    blurRadius: 16,
    spreadRadius: -2,
  );

  static const glowShadow = BoxShadow(
    color: Color(0x1A1685FF),
    offset: Offset(0, 4),
    blurRadius: 16,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardElevated,
            card.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
        boxShadow: premiumShadow,
      );

  static BoxDecoration heroGradient() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: PeeplHomeTokens.feedBackdropGradient,
          stops: [0.0, 0.45, 1.0],
        ),
      );

  static BoxDecoration glassHeroOverlay() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
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
