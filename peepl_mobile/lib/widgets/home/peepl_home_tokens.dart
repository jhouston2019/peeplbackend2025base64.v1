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

  static const yellow = Color(0xFFFFC107);
  static const dealsGreen = Color(0xFF66E38D);

  static const chipBackground = Color(0x1AFFFFFF);
  static const chipBorder = Color(0x0AFFFFFF);
  static const organicCardBorder = Color(0x80FFFFFF); // legacy — organic cards are borderless
  static const organicCardBorderWidth = 1.5;
  static const sponsoredBorder = Color(0xB3FFFFFF);
  static const sponsoredBorderWidth = 2.0;

  static const tickerBackground = Color(0xFF0D2340);
  static const white = Color(0xFFFFFFFF);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const cardFallback = Color(0xFF0D2340);

  static const crowdOverlayLeft = Color(0xF2081A2F);
  static const crowdOverlayMid = Color(0xBF081A2F);
  static const crowdOverlayRight = Color(0x00081A2F);

  static const organicShadow = BoxShadow(
    color: Color(0x28000000),
    offset: Offset(0, 6),
    blurRadius: 22,
    spreadRadius: 0,
  );

  /// Thin white highlight cast to the right edge of organic cards.
  static const organicWhiteShadowRight = BoxShadow(
    color: Color(0x55FFFFFF),
    offset: Offset(2, 0),
    blurRadius: 10,
    spreadRadius: 0,
  );

  /// Thin white highlight cast to the bottom edge of organic cards.
  static const organicWhiteShadowBottom = BoxShadow(
    color: Color(0x55FFFFFF),
    offset: Offset(0, 2),
    blurRadius: 10,
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
  static const halfCardGap = 6.0;
  static const rowVerticalGap = 5.0;
  static const cardRadius = 16.0;
  static const featuredCardHeight = 64.0;
  static const halfCardHeight = 64.0;
  static const sponsoredCardHeight = 64.0;
  static const bottomNavHeight = 56.0;

  // Legacy aliases
  static const navy = shellNavy;
  static const navyHeader = shellNavy;
  static const tickerGreen = dealsGreen;
  static const cardHeight = featuredCardHeight;
  static const cardVerticalGap = rowVerticalGap;
}
