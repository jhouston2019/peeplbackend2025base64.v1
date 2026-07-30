import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import 'crowd_status_panel.dart';
import 'feed_card_image.dart';
import 'peepl_home_tokens.dart';

enum OrganicCardSize { featured, half }

class OrganicCrowdCard extends StatelessWidget {
  const OrganicCrowdCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.crowdData,
    required this.onTap,
    this.distanceLabel,
    this.waitLabel,
    this.size = OrganicCardSize.featured,
    this.marginHorizontal,
  });

  final String imageUrl;
  final String name;
  final CrowdDisplayData crowdData;
  final VoidCallback onTap;
  final String? distanceLabel;
  final String? waitLabel;
  final OrganicCardSize size;
  final double? marginHorizontal;

  double get _height => size == OrganicCardSize.featured
      ? PeeplHomeTokens.featuredCardHeight
      : PeeplHomeTokens.halfCardHeight;

  double get _horizontalMargin =>
      marginHorizontal ??
      (size == OrganicCardSize.featured
          ? PeeplHomeTokens.cardHorizontalMargin
          : 0);

  @override
  Widget build(BuildContext context) {
    final compact = size == OrganicCardSize.half;
    final titleSize = compact ? 12.0 : 14.0;
    final metaSize = compact ? 8.0 : 9.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
            border: Border.all(color: PeeplHomeTokens.organicCardBorder),
            boxShadow: const [PeeplHomeTokens.organicShadow],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
            child: SizedBox(
              height: _height,
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
                            Colors.black.withValues(alpha: 0.06),
                            Colors.black.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CrowdStatusPanel(
                          data: crowdData,
                          compact: compact,
                          showTrend: false,
                        ),
                        Expanded(
                          flex: 7,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              4,
                              compact ? 5 : 6,
                              compact ? 6 : 8,
                              compact ? 5 : 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PeeplHomeTokens.white,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (distanceLabel != null &&
                                        distanceLabel!.isNotEmpty)
                                      Text(
                                        distanceLabel!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: PeeplHomeTokens.white
                                              .withValues(alpha: 0.78),
                                          fontSize: metaSize,
                                          fontWeight: FontWeight.w500,
                                          height: 1.0,
                                        ),
                                      ),
                                    if (waitLabel != null &&
                                        waitLabel!.isNotEmpty)
                                      Text(
                                        waitLabel!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.orange.shade300,
                                          fontSize: metaSize,
                                          fontWeight: FontWeight.w500,
                                          height: 1.0,
                                        ),
                                      ),
                                  ],
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
