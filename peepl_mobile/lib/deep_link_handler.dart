import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import 'services/growth_analytics_service.dart';

/// Handles https://peepl2025v1-production.up.railway.app/p/{peepId} deep links.
class DeepLinkHandler {
  DeepLinkHandler._();

  static String? pendingPeepId;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<Uri>? _linkSub;
  static StreamSubscription<User?>? _authSub;
  static bool _startupComplete = false;
  static final AppLinks _appLinks = AppLinks();

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;

    _navigatorKey = navigatorKey;

    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && pendingPeepId != null) {
        unawaited(processPending());
      }
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink failed: $e');
    }

    await _linkSub?.cancel();
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (Object e) => debugPrint('[DeepLink] uriLinkStream error: $e'),
    );
  }

  static Future<void> dispose() async {
    await _linkSub?.cancel();
    await _authSub?.cancel();
    _linkSub = null;
    _authSub = null;
  }

  static void markStartupComplete() {
    _startupComplete = true;
    unawaited(processPending());
  }

  static Future<void> processPending() async {
    final peepId = pendingPeepId;
    if (peepId == null || peepId.isEmpty) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    pendingPeepId = null;
    await navigateToPeep(peepId);
  }

  static Future<void> _handleUri(Uri uri) async {
    final peepId = _parsePeepId(uri);
    if (peepId == null || peepId.isEmpty) return;

    pendingPeepId = peepId;
    final wasAuthenticated = FirebaseAuth.instance.currentUser != null;

    await GrowthAnalyticsService.logEvent(
      'growth_deep_link_received',
      {
        'peepId': peepId,
        'wasAuthenticated': wasAuthenticated,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (wasAuthenticated && _startupComplete) {
      await processPending();
    }
  }

  static Future<void> navigateToPeep(String peepId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      pendingPeepId = peepId;
      return;
    }

    try {
      var snap = await FirebaseFirestore.instance
          .collection('location_posts')
          .doc(peepId)
          .get();
      if (!snap.exists) {
        snap = await FirebaseFirestore.instance.collection('peeps').doc(peepId).get();
      }
      if (!snap.exists) {
        debugPrint('[DeepLink] Peep not found: $peepId');
        return;
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      await GrowthAnalyticsService.logEvent(
        'growth_deep_link_navigated',
        {
          'peepId': peepId,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final postData = <String, dynamic>{'id': snap.id, ...?snap.data()};
      nav.pushNamed('/location_detail', arguments: postData);
    } catch (e) {
      debugPrint('[DeepLink] navigateToPeep failed: $e');
      pendingPeepId = peepId;
    }
  }

  static String? _parsePeepId(Uri uri) {
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'p') {
      final peepId = uri.pathSegments[1].trim();
      return peepId.isEmpty ? null : peepId;
    }
    return null;
  }
}
