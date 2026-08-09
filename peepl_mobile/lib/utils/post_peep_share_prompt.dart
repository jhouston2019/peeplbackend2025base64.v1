import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/growth_analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/post_peep_share_sheet.dart';

class PostPeepShareArgs {
  const PostPeepShareArgs({
    this.postId,
    required this.locationName,
    required this.crowdingLevel,
    this.fromVenueEntry = false,
  });

  final String? postId;
  final String locationName;
  final int crowdingLevel;
  final bool fromVenueEntry;

  Map<String, dynamic> toMap() => {
        if (postId != null) 'postId': postId,
        'locationName': locationName,
        'crowdingLevel': crowdingLevel,
        'fromVenueEntry': fromVenueEntry,
      };

  static PostPeepShareArgs? fromRoute(
    Object? args, {
    String? widgetLocationName,
  }) {
    if (args is Map<String, dynamic>) {
      return PostPeepShareArgs(
        postId: args['postId'] as String?,
        locationName: (args['locationName'] as String?)?.trim().isNotEmpty == true
            ? (args['locationName'] as String).trim()
            : (widgetLocationName ?? ''),
        crowdingLevel: (args['crowdingLevel'] as num?)?.toInt() ?? 5,
        fromVenueEntry: args['fromVenueEntry'] == true,
      );
    }
    if (args is String && args.trim().isNotEmpty) {
      return PostPeepShareArgs(locationName: args.trim(), crowdingLevel: 5);
    }
    if (widgetLocationName != null && widgetLocationName.trim().isNotEmpty) {
      return PostPeepShareArgs(
        locationName: widgetLocationName.trim(),
        crowdingLevel: 5,
      );
    }
    return null;
  }
}

Future<String> resolvePostPeepShareContext({
  required bool fromVenueEntry,
  required int crowdingLevel,
  required String userId,
}) async {
  if (fromVenueEntry && crowdingLevel >= 8) {
    return 'bring_the_crew';
  }

  try {
    final snap = await FirebaseFirestore.instance
        .collection('location_posts')
        .where('userId', isEqualTo: userId)
        .limit(2)
        .get();
    if (snap.docs.length == 1) {
      return 'first_peep';
    }
  } catch (e) {
    debugPrint('[PostPeepSharePrompt] first peep query failed: $e');
  }

  if (crowdingLevel >= 8) {
    return 'packed';
  }
  return 'standard';
}

Future<void> schedulePostPeepSharePrompt({
  required BuildContext context,
  required PostPeepShareArgs args,
  VoidCallback? onSheetFullyDismissed,
}) async {
  if (!RemoteConfigService.instance.postPeepSharePromptEnabled) {
    onSheetFullyDismissed?.call();
    return;
  }

  final postId = args.postId;
  if (postId == null || postId.isEmpty) {
    await GrowthAnalyticsService.logEvent(
      'growth_share_error',
      {'reason': 'null_postId', 'source': 'post_peep_share_prompt'},
    );
    onSheetFullyDismissed?.call();
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    onSheetFullyDismissed?.call();
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!context.mounted) return;

    final shareContext = await resolvePostPeepShareContext(
      fromVenueEntry: args.fromVenueEntry,
      crowdingLevel: args.crowdingLevel,
      userId: user.uid,
    );

    if (shareContext == 'first_peep') {
      await GrowthAnalyticsService.logEvent(
        'growth_first_peep_detected',
        {'peepId': postId},
      );
    }

    await GrowthAnalyticsService.logEvent(
      'growth_post_peep_share_prompt_shown',
      {
        'peepId': postId,
        'shareContext': shareContext,
        'crowdingLevel': args.crowdingLevel,
        'locationName': args.locationName,
        'fromVenueEntry': args.fromVenueEntry,
      },
    );

    if (!context.mounted) return;

    var dismissAnalyticsLogged = false;
    void logDismissAnalytics() {
      if (dismissAnalyticsLogged) return;
      dismissAnalyticsLogged = true;
      GrowthAnalyticsService.logEvent(
        'growth_post_peep_share_dismissed',
        {
          'peepId': postId,
          'shareContext': shareContext,
        },
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => PostPeepShareSheet(
        peepId: postId,
        locationName: args.locationName,
        crowdingLevel: args.crowdingLevel,
        sharingUserId: user.uid,
        shareContext: shareContext,
        onDismissed: () => Navigator.of(sheetContext).pop(),
        onDismissAnalytics: logDismissAnalytics,
      ),
    ).whenComplete(() {
      logDismissAnalytics();
      onSheetFullyDismissed?.call();
    });
  });
}
