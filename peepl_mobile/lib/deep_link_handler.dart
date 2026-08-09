import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import 'services/growth_analytics_service.dart';

/// Handles Peepl growth deep links (/p/{peepId}, /w/{groupId}).
class DeepLinkHandler {
  DeepLinkHandler._();

  static String? pendingPeepId;
  static String? pendingGroupId;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<Uri>? _linkSub;
  static StreamSubscription<User?>? _authSub;
  static bool _startupComplete = false;
  static final AppLinks _appLinks = AppLinks();

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;

    _navigatorKey = navigatorKey;

    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && (pendingPeepId != null || pendingGroupId != null)) {
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
    if (peepId != null && peepId.isNotEmpty) {
      pendingPeepId = null;
      if (FirebaseAuth.instance.currentUser != null) {
        await navigateToPeep(peepId);
      } else {
        pendingPeepId = peepId;
      }
    }

    final groupId = pendingGroupId;
    if (groupId != null && groupId.isNotEmpty) {
      pendingGroupId = null;
      if (FirebaseAuth.instance.currentUser != null) {
        await navigateToGroup(groupId);
      } else {
        pendingGroupId = groupId;
      }
    }
  }

  static Future<void> _handleUri(Uri uri) async {
    final peepId = _parsePeepId(uri);
    if (peepId != null && peepId.isNotEmpty) {
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
      return;
    }

    final groupId = _parseGroupId(uri);
    if (groupId == null || groupId.isEmpty) return;

    pendingGroupId = groupId;
    final wasAuthenticated = FirebaseAuth.instance.currentUser != null;

    await GrowthAnalyticsService.logEvent(
      'growth_deep_link_received',
      {
        'groupId': groupId,
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

  static Future<void> navigateToGroup(String groupId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      pendingGroupId = groupId;
      return;
    }

    try {
      nav.pushNamed(
        '/where_should_we_go',
        arguments: {'groupId': groupId},
      );
    } catch (e) {
      debugPrint('[DeepLink] navigateToGroup failed: $e');
      pendingGroupId = groupId;
    }
  }

  static String? _parsePeepId(Uri uri) {
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'p') {
      final peepId = uri.pathSegments[1].trim();
      return peepId.isEmpty ? null : peepId;
    }
    return null;
  }

  static String? _parseGroupId(Uri uri) {
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'w') {
      final groupId = uri.pathSegments[1].trim();
      return groupId.isEmpty ? null : groupId;
    }
    return null;
  }
}
