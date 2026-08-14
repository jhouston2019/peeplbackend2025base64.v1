import 'package:flutter/material.dart';

import '../home/peepl_home_tokens.dart';
import 'detail_explore_live_button.dart';
import 'peepl_detail_tokens.dart';

/// Consolidated LIVE NOW module: count, avatars, and Explore Live CTA.
class DetailLiveNowModule extends StatelessWidget {
  const DetailLiveNowModule({
    super.key,
    required this.usernames,
    required this.totalCount,
    required this.isLoading,
    required this.isSubmittingExploreLive,
    required this.onExploreLive,
    this.activityText,
    this.crowdsourceCount,
    this.onPeepHere,
  });

  final List<String> usernames;
  final int totalCount;
  final bool isLoading;
  final bool isSubmittingExploreLive;
  final VoidCallback onExploreLive;
  final String? activityText;
  final int? crowdsourceCount;
  final VoidCallback? onPeepHere;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SizedBox.shrink();

    final displayNames = usernames.take(5).toList();
    final overflow = totalCount - displayNames.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PeeplHomeTokens.actionGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE NOW',
                style: TextStyle(
                  color: PeeplHomeTokens.actionGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            totalCount == 1
                ? '1 person is here now'
                : '$totalCount people are here now',
            style: const TextStyle(
              color: PeeplDetailTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (activityText != null && activityText!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              activityText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PeeplDetailTokens.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (crowdsourceCount != null && crowdsourceCount! > 0) ...[
            const SizedBox(height: 4),
            Text(
              '👀 $crowdsourceCount people want a Peep here',
              style: const TextStyle(
                color: PeeplDetailTokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (totalCount == 0 && onPeepHere != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onPeepHere,
              style: TextButton.styleFrom(
                foregroundColor: PeeplDetailTokens.accentBlue,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Peep Here →',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (displayNames.isNotEmpty)
                SizedBox(
                  height: 36,
                  width: displayNames.length * 24.0 + (overflow > 0 ? 24 : 0),
                  child: Stack(
                    children: [
                      for (var i = 0; i < displayNames.length; i++)
                        Positioned(
                          left: i * 24.0,
                          child: _Avatar(name: displayNames[i]),
                        ),
                      if (overflow > 0)
                        Positioned(
                          left: displayNames.length * 24.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: PeeplDetailTokens.accentBlue
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PeeplDetailTokens.card,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+$overflow',
                              style: const TextStyle(
                                color: PeeplDetailTokens.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const Spacer(),
              DetailExploreLiveButton(
                isLoading: isSubmittingExploreLive,
                onTap: onExploreLive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PeeplDetailTokens.accentBlue,
        border: Border.all(color: PeeplDetailTokens.card, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
