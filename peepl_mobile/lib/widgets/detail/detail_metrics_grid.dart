import 'package:flutter/material.dart';

import 'peepl_detail_tokens.dart';

class DetailMetricItem {
  const DetailMetricItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

/// Single horizontal glass card with four evenly distributed metrics.
class DetailMetricsGrid extends StatelessWidget {
  const DetailMetricsGrid({
    super.key,
    required this.metrics,
    this.secondaryMetrics = const [],
  });

  final List<DetailMetricItem> metrics;
  final List<DetailMetricItem> secondaryMetrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: PeeplDetailTokens.border,
              ),
            Expanded(child: _MetricCell(item: metrics[i])),
          ],
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.item});

  final DetailMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          color: PeeplDetailTokens.accentBlue,
          size: 16,
        ),
        const SizedBox(height: 6),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: PeeplDetailTokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PeeplDetailTokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
