import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import 'peepl_home_tokens.dart';

class TenSegmentCrowdBar extends StatelessWidget {
  const TenSegmentCrowdBar({
    super.key,
    required this.filledSegments,
    required this.fillColor,
    this.segmentCount = 10,
    this.compact = false,
  });

  final int filledSegments;
  final Color fillColor;
  final int segmentCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(segmentCount, (index) {
        final filled = index < filledSegments;
        return Expanded(
          child: Container(
            height: compact ? 3 : 4,
            margin: EdgeInsets.only(right: index < segmentCount - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color: filled
                  ? fillColor
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class CrowdStatusPanel extends StatelessWidget {
  const CrowdStatusPanel({
    super.key,
    required this.data,
    this.compact = false,
    this.showTrend = true,
  });

  final CrowdDisplayData data;
  final bool compact;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final scoreSize = compact ? 14.0 : 17.0;
    final labelSize = compact ? 7.0 : 8.0;

    return Expanded(
      flex: compact ? 4 : 3,
      child: Semantics(
        label: data.semanticLabel,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                PeeplHomeTokens.crowdOverlayLeft,
                PeeplHomeTokens.crowdOverlayMid,
                PeeplHomeTokens.crowdOverlayRight,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 5 : 6,
              compact ? 5 : 6,
              compact ? 3 : 4,
              compact ? 5 : 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.scoreText,
                  style: TextStyle(
                    color: data.color,
                    fontSize: scoreSize,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: compact ? 0 : 1),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data.color,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: compact ? 2 : 3),
                TenSegmentCrowdBar(
                  filledSegments: data.filledSegments,
                  fillColor: data.color,
                  compact: compact,
                ),
                if (showTrend && !compact && data.trendLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TrendIcon(
                        direction: data.trendDirection,
                        color: data.color,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          data.trendLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: data.color.withValues(alpha: 0.9),
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({required this.direction, required this.color});

  final CrowdTrendDirection? direction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (direction) {
      case CrowdTrendDirection.down:
        icon = Icons.arrow_downward;
      case CrowdTrendDirection.up:
        icon = Icons.arrow_upward;
      case CrowdTrendDirection.steady:
      case null:
        icon = Icons.arrow_forward;
    }
    return Icon(icon, size: 9, color: color);
  }
}
