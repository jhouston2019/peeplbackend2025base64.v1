import 'package:flutter/material.dart';

/// Approved premium dark hierarchy for the Peepl home feed shell.
class PeeplHomeTokens {
  PeeplHomeTokens._();

  static const feedBackground = Color(0xFF071522);
  static const shellNavy = Color(0xFF0D2340);
  static const searchField = Color(0xFF1A2F47);
  static const chipSurface = Color(0xFF132538);
  static const skeletonSurface = Color(0xFF0C1A2C);
  static const skeletonHighlight = Color(0xFF132538);

  /// Green = user action / create a Peep.
  static const actionGreen = Color(0xFF22C55E);

  /// Yellow = deals / offers / savings.
  static const dealsYellow = Color(0xFFF4C430);

  /// Black on yellow surfaces (Deals banner + nav).
  static const dealsForeground = Color(0xFF111111);

  static const chipBackground = Color(0x1AFFFFFF);
  static const chipBorder = Color(0x0AFFFFFF);
  static const organicCardBorder = Color(0x38FFFFFF);
  static const organicCardBorderWidth = 2.0;
  static const sponsoredBorder = Color(0xFF2D7BFF);
  static const sponsoredBorderWidth = 2.0;

  /// Premium yellow fill for the CURRENT DEALS banner.
  static const tickerBackground = dealsYellow;
  static const white = Color(0xFFFFFFFF);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const cardFallback = Color(0xFF0D2340);

  static const crowdOverlayLeft = Color(0xF2081A2F);
  static const crowdOverlayMid = Color(0xBF081A2F);
  static const crowdOverlayRight = Color(0x00081A2F);

  static const organicShadow = BoxShadow(
    color: Color(0x59000000),
    offset: Offset(0, 4),
    blurRadius: 12,
    spreadRadius: 0,
  );

  /// Subtle blue edge glow for sponsored hero cards.
  static const sponsoredGlowEdge = BoxShadow(
    color: Color(0x262D7BFF),
    offset: Offset(0, 0),
    blurRadius: 1,
    spreadRadius: 0,
  );

  /// Soft blue drop shadow for sponsored hero cards.
  static const sponsoredGlowDrop = BoxShadow(
    color: Color(0x1A2D7BFF),
    offset: Offset(0, 8),
    blurRadius: 24,
    spreadRadius: 0,
  );

  static const sponsoredShadow = BoxShadow(
    color: Color(0x62000000),
    offset: Offset(0, 4),
    blurRadius: 18,
    spreadRadius: 0,
  );

  static const sponsoredGlow = BoxShadow(
    color: Color(0x120D2340),
    offset: Offset(0, 0),
    blurRadius: 10,
    spreadRadius: 0,
  );

  static const cardHorizontalMargin = 12.0;
  static const sponsoredHorizontalMargin = 16.0;
  static const halfCardGap = 6.0;
  static const rowVerticalGap = 12.0;
  static const cardRadius = 14.0;
  static const featuredCardHeight = 64.0;
  static const halfCardHeight = 64.0;
  static const sponsoredCardHeight = 98.0;
  static const bottomNavHeight = 56.0;

  // Legacy aliases
  static const navy = shellNavy;
  static const navyHeader = shellNavy;
  static const yellow = dealsYellow;
  static const dealsGreen = dealsYellow;
  static const tickerGreen = dealsYellow;
  static const cardHeight = featuredCardHeight;
  static const cardVerticalGap = rowVerticalGap;
}
