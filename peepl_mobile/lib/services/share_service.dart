import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'growth_analytics_service.dart';

/// Centralized share URL generation and share-sheet orchestration.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  static const String baseUrl =
      'https://peepl2025v1-production.up.railway.app';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static String crowdWordLabel(int level) {
    final value = level.clamp(0, 10);
    if (value == 0) return 'Empty';
    if (value <= 2) return 'Quiet';
    if (value <= 4) return 'Moderate';
    if (value <= 6) return 'Busy';
    if (value <= 8) return 'Crowded';
    return 'Packed';
  }

  String buildVenueStatusShareText({
    required String locationName,
    required int crowdingLevel,
    required String shareUrl,
  }) {
    final label = crowdWordLabel(crowdingLevel);
    return '$locationName is $label 🔥 — $crowdingLevel/10 right now '
        'on Peepl → $shareUrl';
  }

  String buildDealShareText({
    required String dealTitle,
    required String venueName,
    required String shareUrl,
  }) {
    return '$dealTitle at $venueName 🍹 — found on Peepl → $shareUrl';
  }

  Future<String> generatePeepShareUrl({
    required String peepId,
    required String sharingUserId,
    required String shareContext,
  }) async {
    final shareId = _uuid.v4();
    final url =
        '$baseUrl/p/$peepId?ref=$shareId&uid=$sharingUserId&src=$shareContext';

    try {
      await _db.collection('peep_shares').doc(shareId).set({
        'shareId': shareId,
        'peepId': peepId,
        'sharingUserId': sharingUserId,
        'sharedAt': FieldValue.serverTimestamp(),
        'shareContext': shareContext,
        'channel': null,
        'type': 'peep_share',
        'shareUrl': url,
      });
    } catch (e) {
      debugPrint('[ShareService] peep_shares write failed: $e');
    }

    return url;
  }

  String buildShareText({
    required String locationName,
    required int crowdingLevel,
    required String shareUrl,
    String shareContext = 'default',
  }) {
    if (crowdingLevel >= 8 && shareContext == 'bring_the_crew') {
      return '$locationName is PACKED 🔥 — $crowdingLevel/10 '
          'right now. Come meet us. See it live → $shareUrl';
    }
    if (crowdingLevel >= 8) {
      return '$locationName is PACKED 🔥 — $crowdingLevel/10 '
          'right now. See the live Peep → $shareUrl';
    }
    if (crowdingLevel >= 5) {
      return '$locationName is about $crowdingLevel/10 right now. '
          "See what's happening → $shareUrl";
    }
    if (crowdingLevel <= 4) {
      return '$locationName is pretty quiet right now — '
          '$crowdingLevel/10. Good time to go → $shareUrl';
    }
    if (shareContext == 'venue_share') {
      return "See what's happening at $locationName on Peepl → $shareUrl";
    }
    return '$locationName — $crowdingLevel/10 right now → $shareUrl';
  }

  Future<void> sharePeep({
    required String peepId,
    required String locationName,
    required int crowdingLevel,
    required String sharingUserId,
    String shareContext = 'default',
  }) async {
    try {
      if (peepId.isEmpty) {
        await GrowthAnalyticsService.logEvent(
          'growth_share_error',
          {'reason': 'null_peepId', 'shareContext': shareContext},
        );
        return;
      }

      await GrowthAnalyticsService.logEvent(
        'growth_share_initiated',
        {
          'peepId': peepId,
          'sharingUserId': sharingUserId,
          'shareContext': shareContext,
          'crowdingLevel': crowdingLevel,
          'locationName': locationName,
        },
      );

      final shareUrl = await generatePeepShareUrl(
        peepId: peepId,
        sharingUserId: sharingUserId,
        shareContext: shareContext,
      );
      final shareId = Uri.parse(shareUrl).queryParameters['ref'];
      final text = buildShareText(
        locationName: locationName,
        crowdingLevel: crowdingLevel,
        shareUrl: shareUrl,
        shareContext: shareContext,
      );

      await Share.share(text);

      await GrowthAnalyticsService.logEvent(
        'growth_share_completed',
        {
          'peepId': peepId,
          if (shareId != null) 'shareId': shareId,
          'sharingUserId': sharingUserId,
          'shareContext': shareContext,
        },
      );
    } catch (e) {
      debugPrint('[ShareService] sharePeep failed: $e');
    }
  }

  Future<void> shareVenueStatus({
    required String locationName,
    required int crowdingLevel,
    required String sharingUserId,
    String? venueId,
  }) async {
    try {
      const shareContext = 'venue_share';
      final shareId = _uuid.v4();
      final pathSegment = venueId ?? Uri.encodeComponent(locationName);
      final shareUrl =
          '$baseUrl/v/$pathSegment?ref=$shareId&uid=$sharingUserId&src=$shareContext';

      try {
        await _db.collection('peep_shares').doc(shareId).set({
          'shareId': shareId,
          'peepId': venueId ?? locationName,
          'sharingUserId': sharingUserId,
          'sharedAt': FieldValue.serverTimestamp(),
          'shareContext': shareContext,
          'channel': null,
          'type': 'venue_share',
          'shareUrl': shareUrl,
          'locationName': locationName,
          'crowdingLevel': crowdingLevel,
          if (venueId != null) 'venueId': venueId,
        });
      } catch (e) {
        debugPrint('[ShareService] venue peep_shares write failed: $e');
      }

      await GrowthAnalyticsService.logEvent(
        'growth_venue_status_shared',
        {
          'locationName': locationName,
          if (venueId != null) 'venueId': venueId,
          'crowdingLevel': crowdingLevel,
          'sharingUserId': sharingUserId,
          'shareId': shareId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final text = buildVenueStatusShareText(
        locationName: locationName,
        crowdingLevel: crowdingLevel,
        shareUrl: shareUrl,
      );

      await Share.share(text);
    } catch (e) {
      debugPrint('[ShareService] shareVenueStatus failed: $e');
    }
  }

  Future<void> shareDeal({
    required String dealId,
    required String dealTitle,
    required String venueName,
    required String sharingUserId,
  }) async {
    try {
      if (dealId.isEmpty) {
        await GrowthAnalyticsService.logEvent(
          'growth_share_error',
          {'reason': 'null_dealId', 'shareContext': 'deal_share'},
        );
        return;
      }

      const shareContext = 'deal_share';
      final shareId = _uuid.v4();
      final shareUrl =
          '$baseUrl/d/$dealId?ref=$shareId&uid=$sharingUserId&src=$shareContext';

      try {
        await _db.collection('peep_shares').doc(shareId).set({
          'shareId': shareId,
          'dealId': dealId,
          'dealTitle': dealTitle,
          'venueName': venueName,
          'sharingUserId': sharingUserId,
          'sharedAt': FieldValue.serverTimestamp(),
          'shareContext': shareContext,
          'channel': null,
          'type': 'deal_share',
          'shareUrl': shareUrl,
        });
      } catch (e) {
        debugPrint('[ShareService] deal peep_shares write failed: $e');
      }

      await GrowthAnalyticsService.logEvent(
        'growth_deal_shared',
        {
          'dealId': dealId,
          'dealTitle': dealTitle,
          'venueName': venueName,
          'sharingUserId': sharingUserId,
          'shareId': shareId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final text = buildDealShareText(
        dealTitle: dealTitle,
        venueName: venueName,
        shareUrl: shareUrl,
      );

      await Share.share(text);
    } catch (e) {
      debugPrint('[ShareService] shareDeal failed: $e');
    }
  }

  /// Builds share text for preview/copy without opening the share sheet.
  Future<String> buildPeepShareMessage({
    required String peepId,
    required String locationName,
    required int crowdingLevel,
    required String sharingUserId,
    String shareContext = 'share_screen',
  }) async {
    final shareUrl = await generatePeepShareUrl(
      peepId: peepId,
      sharingUserId: sharingUserId,
      shareContext: shareContext,
    );
    return buildShareText(
      locationName: locationName,
      crowdingLevel: crowdingLevel,
      shareUrl: shareUrl,
      shareContext: shareContext,
    );
  }

  /// Builds venue share text for preview/copy without opening the share sheet.
  Future<String> buildVenueShareMessage({
    required String locationName,
    required int crowdingLevel,
    required String sharingUserId,
    String? venueId,
  }) async {
    final shareId = _uuid.v4();
    final pathSegment = venueId ?? Uri.encodeComponent(locationName);
    const shareContext = 'venue_share';
    final shareUrl =
        '$baseUrl/v/$pathSegment?ref=$shareId&uid=$sharingUserId&src=$shareContext';

    try {
      await _db.collection('peep_shares').doc(shareId).set({
        'shareId': shareId,
        'peepId': venueId ?? locationName,
        'sharingUserId': sharingUserId,
        'sharedAt': FieldValue.serverTimestamp(),
        'shareContext': shareContext,
        'channel': null,
        'type': 'venue_share',
        'shareUrl': shareUrl,
        'locationName': locationName,
        'crowdingLevel': crowdingLevel,
        if (venueId != null) 'venueId': venueId,
      });
    } catch (e) {
      debugPrint('[ShareService] venue peep_shares write failed: $e');
    }

    return buildVenueStatusShareText(
      locationName: locationName,
      crowdingLevel: crowdingLevel,
      shareUrl: shareUrl,
    );
  }
}
