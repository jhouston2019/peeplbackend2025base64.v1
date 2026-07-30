import 'package:flutter/material.dart';

/// Approved premium dark hierarchy for the Peepl home feed shell.
class PeeplHomeTokens {
  PeeplHomeTokens._();

  /// Darkest navy — primary screen background.
  static const feedBackground = Color(0xFF081A2F);

  /// Slightly lighter navy — header and bottom navigation.
  static const shellNavy = Color(0xFF0D2340);

  /// Charcoal with navy tint — search and quick-action chips.
  static const searchField = Color(0xFF1A2F47);
  static const chipSurface = Color(0xFF132538);

  static const yellow = Color(0xFFFFC107);
  static const dealsGreen = Color(0xFF66E38D);

  static const chipBackground = Color(0x1AFFFFFF);
  static const chipBorder = Color(0x14FFFFFF);
  static const organicCardBorder = Color(0x14FFFFFF);

  static const tickerBackground = Color(0xFF0D2340);
  static const white = Color(0xFFFFFFFF);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const cardFallback = Color(0xFF0D2340);
  static const sponsoredBorder = Color(0x24FFFFFF);

  /// Crowd panel gradient stops (left → right).
  static const crowdOverlayLeft = Color(0xF2081A2F);
  static const crowdOverlayMid = Color(0xBF081A2F);
  static const crowdOverlayRight = Color(0x00081A2F);

  static const cardHorizontalMargin = 14.0;
  static const cardVerticalGap = 7.0;
  static const cardRadius = 14.0;
  static const cardHeight = 136.0;
  static const sponsoredCardHeight = 144.0;
  static const bottomNavHeight = 56.0;

  // Legacy aliases used by a few call sites.
  static const navy = shellNavy;
  static const navyHeader = shellNavy;
  static const tickerGreen = dealsGreen;
}
