import 'dart:async';

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
    final scoreSize = compact ? 15.0 : 19.0;
    final labelSize = compact ? 6.5 : 7.0;

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
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: compact ? 0 : 1),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data.color.withValues(alpha: 0.88),
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
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
                  _AnimatedTrendIndicator(
                    direction: data.trendDirection,
                    color: data.color,
                    label: data.trendLabel!,
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

class _AnimatedTrendIndicator extends StatefulWidget {
  const _AnimatedTrendIndicator({
    required this.direction,
    required this.color,
    required this.label,
  });

  final CrowdTrendDirection? direction;
  final Color color;
  final String label;

  @override
  State<_AnimatedTrendIndicator> createState() =>
      _AnimatedTrendIndicatorState();
}

class _AnimatedTrendIndicatorState extends State<_AnimatedTrendIndicator> {
  bool _pulse = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPulse());
  }

  void _startPulse() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _pulse = true);
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _pulse = false);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      opacity: disableAnimations ? 1.0 : (_pulse ? 1.0 : 0.82),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        offset: disableAnimations ? Offset.zero : Offset(0, _pulse ? -0.04 : 0),
        child: Row(
          children: [
            _TrendIcon(
              direction: widget.direction,
              color: widget.color,
              glow: _pulse && !disableAnimations,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.82),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({
    required this.direction,
    required this.color,
    this.glow = false,
  });

  final CrowdTrendDirection? direction;
  final Color color;
  final bool glow;

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

    final iconWidget = Icon(icon, size: 9, color: color);

    if (!glow) return iconWidget;

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: iconWidget,
    );
  }
}
