import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import 'crowd_status_panel.dart';
import 'feed_card_image.dart';
import 'peepl_home_tokens.dart';

class OrganicCrowdCard extends StatelessWidget {
  const OrganicCrowdCard({
    super.key,
    required this.imageUrl,
    required this.name,
    this.categoryLine,
    this.metaItems = const [],
    required this.crowdData,
    required this.onTap,
  });

  final String imageUrl;
  final String name;
  final String? categoryLine;
  final List<OrganicMetaItem> metaItems;
  final CrowdDisplayData crowdData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PeeplHomeTokens.cardHorizontalMargin,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
            border: Border.all(color: PeeplHomeTokens.organicCardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
            child: SizedBox(
              height: PeeplHomeTokens.cardHeight,
              child: Stack(
              fit: StackFit.expand,
              children: [
                FeedCardImage(source: imageUrl),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CrowdStatusPanel(data: crowdData),
                      Expanded(
                        flex: 7,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PeeplHomeTokens.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              if (categoryLine != null &&
                                  categoryLine!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  categoryLine!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PeeplHomeTokens.white
                                        .withValues(alpha: 0.72),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (metaItems.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: metaItems
                                      .map((item) => _MetaChip(item: item))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class OrganicMetaItem {
  const OrganicMetaItem({
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.item});

  final OrganicMetaItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? PeeplHomeTokens.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          item.label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
