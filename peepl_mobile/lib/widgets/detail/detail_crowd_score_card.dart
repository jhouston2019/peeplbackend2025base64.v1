import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import '../crowd_meter.dart';
import 'peepl_detail_tokens.dart';

class DetailCrowdScoreCard extends StatelessWidget {
  const DetailCrowdScoreCard({
    super.key,
    required this.crowdingLevel,
    this.trendRaw,
  });

  final int crowdingLevel;
  final String? trendRaw;

  @override
  Widget build(BuildContext context) {
    final crowdData = CrowdDisplayMapper.fromScore(
      crowdingLevel,
      trendRaw: trendRaw,
    );
    final statusColor = CrowdMeter.levelColor(crowdingLevel);
    final statusLabel = CrowdMeter.wordLabel(crowdingLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: PeeplDetailTokens.cardDecoration(
        color: PeeplDetailTokens.cardElevated,
      ),
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
                    color: PeeplDetailTokens.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
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
                            color: PeeplDetailTokens.textSecondary,
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
