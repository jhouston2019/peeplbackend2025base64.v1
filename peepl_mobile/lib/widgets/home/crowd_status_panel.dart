import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';

class TenSegmentCrowdBar extends StatelessWidget {
  const TenSegmentCrowdBar({
    super.key,
    required this.filledSegments,
    required this.fillColor,
    this.segmentCount = 10,
  });

  final int filledSegments;
  final Color fillColor;
  final int segmentCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(segmentCount, (index) {
        final filled = index < filledSegments;
        return Expanded(
          child: Container(
            height: 4,
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
  });

  final CrowdDisplayData data;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Semantics(
        label: data.semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
              ],
              stops: const [0.0, 0.75, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.scoreText,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                TenSegmentCrowdBar(
                  filledSegments: data.filledSegments,
                  fillColor: data.color,
                ),
                if (data.trendLabel != null) ...[
                  const SizedBox(height: 5),
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
                            fontSize: 8,
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
    return Icon(icon, size: 10, color: color);
  }
}
