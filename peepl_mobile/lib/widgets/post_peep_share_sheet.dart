import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/growth_analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/share_service.dart';
import 'peepl_positive_message.dart';

class PostPeepShareSheet extends StatelessWidget {
  const PostPeepShareSheet({
    super.key,
    required this.peepId,
    required this.locationName,
    required this.crowdingLevel,
    required this.sharingUserId,
    required this.shareContext,
    required this.onDismissed,
    required this.onDismissAnalytics,
  });

  final String peepId;
  final String locationName;
  final int crowdingLevel;
  final String sharingUserId;
  final String shareContext;
  final VoidCallback onDismissed;
  final VoidCallback onDismissAnalytics;

  bool get _showStoryButton =>
      RemoteConfigService.instance.publicSocialSharingEnabled &&
      shareContext == 'bring_the_crew';

  ({String headline, String subtext, String? primaryLabel, String? secondaryLabel, String dismissLabel})
      get _copy {
    switch (shareContext) {
      case 'bring_the_crew':
        return (
          headline: 'Bring the crew? 🔥',
          subtext: '$locationName is packed. Tell your people.',
          primaryLabel: 'Text Friends',
          secondaryLabel: 'Share',
          dismissLabel: 'Not now',
        );
      case 'first_peep':
        return (
          headline: 'You just Peeped! 👀',
          subtext: "Tell someone what's happening.",
          primaryLabel: 'Share Your Peep',
          secondaryLabel: null,
          dismissLabel: 'Maybe later',
        );
      case 'packed':
        return (
          headline: "It's packed in there 🔥",
          subtext: 'Someone should know.',
          primaryLabel: 'Share',
          secondaryLabel: null,
          dismissLabel: 'Done',
        );
      default:
        return (
          headline: 'Peep sent ✓',
          subtext: "Share what's happening.",
          primaryLabel: 'Share',
          secondaryLabel: null,
          dismissLabel: 'Done',
        );
    }
  }

  Future<void> _launchShareSheet(BuildContext context) async {
    try {
      await GrowthAnalyticsService.logEvent(
        'growth_post_peep_share_initiated',
        {
          'peepId': peepId,
          'shareContext': shareContext,
          'channel': 'sheet',
        },
      );
      await ShareService.instance.sharePeep(
        peepId: peepId,
        locationName: locationName,
        crowdingLevel: crowdingLevel,
        sharingUserId: sharingUserId,
        shareContext: shareContext,
      );
    } catch (e) {
      debugPrint('[PostPeepShareSheet] share failed: $e');
    }
    if (context.mounted) onDismissed();
  }

  Future<void> _launchSms(BuildContext context) async {
    try {
      await GrowthAnalyticsService.logEvent(
        'growth_post_peep_share_initiated',
        {
          'peepId': peepId,
          'shareContext': shareContext,
          'channel': 'sms',
        },
      );

      final shareUrl = await ShareService.instance.generatePeepShareUrl(
        peepId: peepId,
        sharingUserId: sharingUserId,
        shareContext: shareContext,
      );
      final text = ShareService.instance.buildShareText(
        locationName: locationName,
        crowdingLevel: crowdingLevel,
        shareUrl: shareUrl,
        shareContext: shareContext,
      );
      final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');

      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      } else {
        await ShareService.instance.sharePeep(
          peepId: peepId,
          locationName: locationName,
          crowdingLevel: crowdingLevel,
          sharingUserId: sharingUserId,
          shareContext: shareContext,
        );
      }
    } catch (e) {
      debugPrint('[PostPeepShareSheet] SMS failed, falling back: $e');
      try {
        await ShareService.instance.sharePeep(
          peepId: peepId,
          locationName: locationName,
          crowdingLevel: crowdingLevel,
          sharingUserId: sharingUserId,
          shareContext: shareContext,
        );
      } catch (_) {}
    }
    if (context.mounted) onDismissed();
  }

  Future<void> _launchSocialCard(BuildContext context) async {
    try {
      await ShareService.instance.generateSocialCard(
        peepId: peepId,
        locationName: locationName,
        crowdingLevel: crowdingLevel,
        sharingUserId: sharingUserId,
      );
    } on UnimplementedError catch (e) {
      debugPrint('[PostPeepShareSheet] social card stub: $e');
    } catch (e) {
      debugPrint('[PostPeepShareSheet] social card failed: $e');
    }
    if (context.mounted) onDismissed();
  }

  void _dismissWithAnalytics() {
    onDismissAnalytics();
    onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            copy.headline,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy.subtext,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          if (copy.primaryLabel != null)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: shareContext == 'bring_the_crew'
                    ? () => _launchSms(context)
                    : () => _launchShareSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(copy.primaryLabel!),
              ),
            ),
          if (copy.secondaryLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _launchShareSheet(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(copy.secondaryLabel!),
              ),
            ),
          ],
          if (_showStoryButton) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _launchSocialCard(context),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Share to Story'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: _dismissWithAnalytics,
            child: Text(
              copy.dismissLabel,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
          PeeplPositiveMessage(
            contextKey: 'post_peep_share_$shareContext',
          ),
        ],
      ),
    );
  }
}
