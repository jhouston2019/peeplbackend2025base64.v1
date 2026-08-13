import 'package:flutter/material.dart';

/// Approved light-shell + full-bleed feed tokens for the Peepl home feed.
class PeeplHomeTokens {
  PeeplHomeTokens._();

  // --- Page background (light frosted environmental shell) ---
  static const feedBackground = Color(0xFFE6EEF5);
  static const feedFrostOverlay = Color(0x66F5F9FC);
  static const feedBokehSky = Color(0xFF9FD4FF);
  static const feedBokehMint = Color(0xFFB8E8D0);
  static const feedBokehWarm = Color(0xFFFFE0A8);
  static const feedBackdropGradient = [
    Color(0xFFEAF2F8),
    Color(0xFFDCEAF4),
    Color(0xFFE8F0F6),
    Color(0xFFD8E6F0),
  ];

  /// Header / selected chip navy (not a page background).
  static const shellNavy = Color(0xFF0D2340);
  static const headerForeground = Color(0xFF1B2A3A);
  static const headerMuted = Color(0xFF5A6B7A);
  static const searchField = Color(0xFFF3F7FA);
  static const chipSurface = Color(0xCCFFFFFF);
  static const chipBorderLight = Color(0x66FFFFFF);
  static const skeletonSurface = Color(0x33FFFFFF);
  static const skeletonHighlight = Color(0x55FFFFFF);
  static const frostedNav = Color(0xBFF5F9FC);
  static const frostedNavBorder = Color(0x33FFFFFF);

  /// Peepl brand blue (wordmark + sponsored border).
  static const brandBlue = Color(0xFF1685FF);

  /// Green = user action / create a Peep.
  static const actionGreen = Color(0xFF48EF72);

  /// Yellow = deals / offers / savings.
  static const dealsYellow = Color(0xFFFFD447);

  /// Black on yellow surfaces (Deals banner + nav).
  static const dealsForeground = Color(0xFF111111);

  static const chipBackground = Color(0xCCFFFFFF);
  static const chipBorder = Color(0x33FFFFFF);
  static const organicSeparator = Color(0x80DCE1E6);
  static const organicCardBorder = organicSeparator;
  static const organicCardBorderWidth = 1.0;
  static const sponsoredBorder = brandBlue;
  static const sponsoredBorderWidth = 2.0;

  /// Premium yellow fill for the CURRENT DEALS banner.
  static const tickerBackground = dealsYellow;
  static const white = Color(0xFFFFFFFF);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const cardFallback = Color(0xFF1A2B3A);

  /// Full-card organic overlay (no separate score panel).
  static const crowdOverlayLeft = Color(0xE0050F19);
  static const crowdOverlayMid = Color(0x99050F19);
  static const crowdOverlayRight = Color(0x26050F19);

  /// Pastel crowd palette.
  static const crowdLight = Color(0xFF5DBBFF);
  static const crowdMedium = Color(0xFFB56CFF);
  static const crowdHigh = Color(0xFFFF6474);
  static const crowdDotEmpty = Color(0x73C8CDD2);

  static const sponsoredGlowEdge = BoxShadow(
    color: Color(0x331685FF),
    offset: Offset(0, 0),
    blurRadius: 1,
    spreadRadius: 0,
  );

  static const sponsoredGlowDrop = BoxShadow(
    color: Color(0x1A1685FF),
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

  static const cardHorizontalMargin = 0.0;
  static const sponsoredHorizontalMargin = 16.0;
  static const halfCardGap = 1.0;
  static const rowVerticalGap = 12.0;
  static const cardRadius = 0.0;
  static const sponsoredCardRadius = 12.0;
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
  static const organicShadow = BoxShadow(color: Colors.transparent);
}
