import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NativeAdsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Scoring constants ──────────────────────────────────────────────────────
  static const Map<String, int> _tierBaseScore = {
    'premium': 100,
    'standard': 60,
    'basic': 30,
  };

  /// Default radius used when a native_ads document omits [targetRadiusKm].
  static const double defaultTargetRadiusKm = 20.0;

  /// Distance beyond which a user is considered to be vicariously peepling
  /// (clearly not physically present at the venues they're browsing).
  static const double vicariousThresholdKm = 80.0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns active ads whose campaign window covers right now, scored and
  /// filtered by the user's location when [userLat]/[userLng] are supplied.
  ///
  /// **Scoring** (applied client-side after the Firestore fetch):
  ///   tier score  premium=100 / standard=60 / basic=30
  ///   dist bonus  <1 km=+50  <5 km=+35  <20 km=+15  ≥20 km=+0
  ///   geo-first   ads with no venueLat/venueLng always sort to the bottom
  ///
  /// **Radius filter** — ads with a venueLat/venueLng set are hard-filtered
  /// against the user's position using the ad's [targetRadiusKm] field
  /// (default [defaultTargetRadiusKm]). Ads with no venue coords are served
  /// everywhere (national/brand ads).
  ///
  /// **Context targeting**:
  ///   'feed'    — no context filter (maximum fill)
  ///   'discover'— contexts arrayContains 'discover'
  ///   'venue'   — contexts arrayContains 'venue'
  ///   'travel'  — contexts arrayContains 'travel' (vicarious peepling)
  ///
  /// NOTE: The startDate + endDate double-range filter requires a composite
  /// Firestore index on (isActive, endDate, startDate, priority). Firestore
  /// will log a console link to create it automatically on first run.
  Future<List<Map<String, dynamic>>> getAdsForFeed({
    String? userLocation,
    List<String>? userInterests,
    String context = 'feed',
    int limit = 10,
    double? userLat,
    double? userLng,
  }) async {
    try {
      // Single inequality on endDate — Firestore requires the first orderBy()
      // to match the inequality field. The startDate filter is omitted here;
      // isActive:true is set by the backend when an ad's start time is reached.
      Query query = _firestore
          .collection('native_ads')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now());

      // Context targeting — 'feed' is unfiltered for maximum inventory fill.
      switch (context) {
        case 'discover':
          query = query.where('contexts', arrayContains: 'discover');
        case 'venue':
          query = query.where('contexts', arrayContains: 'venue');
        case 'travel':
          query = query.where('contexts', arrayContains: 'travel');
        default:
          break; // 'feed': no filter
      }

      if (userLocation != null) {
        query = query.where('targetLocations', arrayContains: userLocation);
      }

      // Fetch a generous pool so client-side filtering doesn't leave us short.
      final fetchLimit = userLat != null ? (limit * 3).clamp(10, 30) : limit;
      final snapshot = await query
          .orderBy('endDate')
          .orderBy('priority', descending: true)
          .limit(fetchLimit)
          .get();

      var ads = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      // Client-side location processing (radius filter + scoring + sort).
      if (userLat != null && userLng != null) {
        ads = _filterByRadius(ads, userLat, userLng);
        ads = _sortByScore(ads, userLat, userLng);
      }

      return ads.take(limit).toList();
    } catch (e) {
      debugPrint('NativeAdsService.getAdsForFeed error: $e');
      return [];
    }
  }

  Future<void> recordAdClick(String adId, String userId) async {
    await recordAdEvent(
      adId: adId,
      userId: userId,
      event: 'click',
    );
  }

  /// Unified feed analytics: impression, viewable, card_tap, cta_tap.
  ///
  /// [feedPlacement] — stream position (4, 7, 11, 14 …) for CTR-by-slot.
  /// [advertiserId] — enables CTR-by-advertiser rollups.
  Future<void> recordAdEvent({
    required String adId,
    required String userId,
    required String event,
    int? feedPlacement,
    String? advertiserId,
    String context = 'feed',
  }) async {
    if (adId.isEmpty || adId.startsWith('dummy_')) return;
    try {
      final payload = <String, dynamic>{
        'adId': adId,
        'userId': userId,
        'event': event,
        'context': context,
        'timestamp': FieldValue.serverTimestamp(),
        if (feedPlacement != null) 'feedPlacement': feedPlacement,
        if (advertiserId != null && advertiserId.isNotEmpty)
          'advertiserId': advertiserId,
      };
      await _firestore.collection('ad_events').add(payload);

      switch (event) {
        case 'impression':
          await _firestore.collection('native_ads').doc(adId).update({
            'impressions': FieldValue.increment(1),
          });
        case 'viewable':
          break;
        case 'card_tap':
        case 'cta_tap':
        case 'click':
          await _firestore.collection('native_ads').doc(adId).update({
            'clicks': FieldValue.increment(1),
          });
      }
    } catch (e) {
      debugPrint('NativeAdsService.recordAdEvent($event) error: $e');
    }
  }

  Future<void> recordAdImpression(
    String adId,
    String userId, {
    int? feedPlacement,
    String? advertiserId,
  }) =>
      recordAdEvent(
        adId: adId,
        userId: userId,
        event: 'impression',
        feedPlacement: feedPlacement,
        advertiserId: advertiserId,
      );

  Future<void> recordAdViewability(
    String adId,
    String userId, {
    int? feedPlacement,
    String? advertiserId,
  }) =>
      recordAdEvent(
        adId: adId,
        userId: userId,
        event: 'viewable',
        feedPlacement: feedPlacement,
        advertiserId: advertiserId,
      );

  Future<void> recordAdCardTap(
    String adId,
    String userId, {
    int? feedPlacement,
    String? advertiserId,
  }) =>
      recordAdEvent(
        adId: adId,
        userId: userId,
        event: 'card_tap',
        feedPlacement: feedPlacement,
        advertiserId: advertiserId,
      );

  Future<void> recordAdCtaTap(
    String adId,
    String userId, {
    int? feedPlacement,
    String? advertiserId,
  }) =>
      recordAdEvent(
        adId: adId,
        userId: userId,
        event: 'cta_tap',
        feedPlacement: feedPlacement,
        advertiserId: advertiserId,
      );

  // ── Static helpers ─────────────────────────────────────────────────────────

  /// Returns true when the user is browsing venues they are clearly not
  /// physically near — i.e. they are "vicariously peepling" remotely.
  /// Threshold: [vicariousThresholdKm] (80 km by default).
  static bool detectVicariousPeepling({
    required double userLat,
    required double userLng,
    required double venueLat,
    required double venueLng,
  }) {
    return _haversineKm(userLat, userLng, venueLat, venueLng) >
        vicariousThresholdKm;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Remove ads whose venue is outside their declared [targetRadiusKm].
  /// Ads with no venue coords are kept (national / brand campaigns).
  static List<Map<String, dynamic>> _filterByRadius(
    List<Map<String, dynamic>> ads,
    double userLat,
    double userLng,
  ) {
    return ads.where((ad) {
      final adLat = _toDouble(ad['venueLat']);
      final adLng = _toDouble(ad['venueLng']);
      if (adLat == null || adLng == null) return true;
      final radius =
          _toDouble(ad['targetRadiusKm']) ?? defaultTargetRadiusKm;
      return _haversineKm(userLat, userLng, adLat, adLng) <= radius;
    }).toList();
  }

  /// Sort ads: geo-targeted ads first (by descending composite score),
  /// no-location ads last (sorted among themselves by tier score only).
  static List<Map<String, dynamic>> _sortByScore(
    List<Map<String, dynamic>> ads,
    double userLat,
    double userLng,
  ) {
    return ads..sort((a, b) {
      final aHasGeo =
          _toDouble(a['venueLat']) != null && _toDouble(a['venueLng']) != null;
      final bHasGeo =
          _toDouble(b['venueLat']) != null && _toDouble(b['venueLng']) != null;

      // Geo-targeted ads always precede no-location ads.
      if (aHasGeo && !bHasGeo) return -1;
      if (!aHasGeo && bHasGeo) return 1;

      // Within the same geo group, sort by composite score descending.
      final sa = _scoreAd(a, userLat, userLng);
      final sb = _scoreAd(b, userLat, userLng);
      return sb.compareTo(sa);
    });
  }

  /// Composite score = tier base + distance bonus.
  /// Used for ranking; not stored on the document.
  static double _scoreAd(
    Map<String, dynamic> ad,
    double userLat,
    double userLng,
  ) {
    final tierScore =
        (_tierBaseScore[ad['tier'] as String? ?? ''] ?? 30).toDouble();

    final adLat = _toDouble(ad['venueLat']);
    final adLng = _toDouble(ad['venueLng']);
    if (adLat == null || adLng == null) return tierScore;

    final distKm = _haversineKm(userLat, userLng, adLat, adLng);
    final distScore = distKm < 1
        ? 50
        : distKm < 5
            ? 35
            : distKm < 20
                ? 15
                : 0;

    return tierScore + distScore;
  }

  /// Haversine great-circle distance in kilometres.
  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1) *
            math.cos(p2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }
}
