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
    if (metrics.isEmpty && secondaryMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (metrics.isNotEmpty) _buildGrid(metrics),
        if (secondaryMetrics.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildGrid(secondaryMetrics),
        ],
      ],
    );
  }

  Widget _buildGrid(List<DetailMetricItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _MetricCard(item: items[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final DetailMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: PeeplDetailTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: PeeplDetailTokens.accentBlue,
            size: 18,
          ),
          const Spacer(),
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
            style: const TextStyle(
              color: PeeplDetailTokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
