import 'package:flutter/material.dart';

/// Approved premium dark hierarchy for the Peepl home feed shell.
class PeeplHomeTokens {
  PeeplHomeTokens._();

  static const feedBackground = Color(0xFF081A2F);
  static const shellNavy = Color(0xFF0D2340);
  static const searchField = Color(0xFF1A2F47);
  static const chipSurface = Color(0xFF132538);

  static const yellow = Color(0xFFFFC107);
  static const dealsGreen = Color(0xFF66E38D);

  static const chipBackground = Color(0x1AFFFFFF);
  static const chipBorder = Color(0x14FFFFFF);
  static const organicCardBorder = Color(0x80FFFFFF); // 50% soft white
  static const organicCardBorderWidth = 1.5;
  static const sponsoredBorder = Color(0x24FFFFFF);

  static const tickerBackground = Color(0xFF0D2340);
  static const white = Color(0xFFFFFFFF);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const cardFallback = Color(0xFF0D2340);

  static const crowdOverlayLeft = Color(0xF2081A2F);
  static const crowdOverlayMid = Color(0xBF081A2F);
  static const crowdOverlayRight = Color(0x00081A2F);

  static const organicShadow = BoxShadow(
    color: Color(0x47000000),
    offset: Offset(0, 2),
    blurRadius: 12,
    spreadRadius: 0,
  );

  static const sponsoredShadow = BoxShadow(
    color: Color(0x52000000),
    offset: Offset(0, 2),
    blurRadius: 14,
    spreadRadius: 0,
  );

  static const cardHorizontalMargin = 12.0;
  static const halfCardGap = 6.0;
  static const rowVerticalGap = 3.0;
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
