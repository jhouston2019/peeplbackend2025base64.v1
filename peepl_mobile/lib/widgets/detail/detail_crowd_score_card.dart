import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import '../crowd_meter.dart';
import '../home/peepl_home_tokens.dart';
import 'peepl_detail_tokens.dart';

class DetailCrowdScoreCard extends StatelessWidget {
  const DetailCrowdScoreCard({
    super.key,
    required this.crowdingLevel,
    this.trendRaw,
    this.contributorCount,
    this.isLive = false,
  });

  final int crowdingLevel;
  final String? trendRaw;
  final int? contributorCount;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final crowdData = CrowdDisplayMapper.fromScore(
      crowdingLevel,
      trendRaw: trendRaw,
    );
    final statusColor = CrowdMeter.levelColor(crowdingLevel);
    final statusLabel = CrowdMeter.wordLabel(crowdingLevel);

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: Row(
        children: [
          CrowdMeter(level: crowdingLevel, size: 72, fontScale: 0.38),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crowd Score',
                  style: TextStyle(
                    color: PeeplDetailTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (isLive) ...[
                  const SizedBox(height: 8),
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
                      const SizedBox(width: 6),
                      Text(
                        'Active right now',
                        style: TextStyle(
                          color: PeeplDetailTokens.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (crowdData.trendLabel != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _trendIcon(crowdData.trendDirection),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          crowdData.trendLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PeeplDetailTokens.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _trendIcon(CrowdTrendDirection? direction) {
    switch (direction) {
      case CrowdTrendDirection.down:
        return Icons.trending_down_rounded;
      case CrowdTrendDirection.up:
        return Icons.trending_up_rounded;
      case CrowdTrendDirection.steady:
      case null:
        return Icons.trending_flat_rounded;
    }
  }
}
