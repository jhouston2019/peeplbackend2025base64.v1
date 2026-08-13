import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import 'crowd_status_panel.dart';
import 'feed_card_image.dart';
import 'feed_card_tap_scale.dart';
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
      marginHorizontal ?? PeeplHomeTokens.cardHorizontalMargin;

  @override
  Widget build(BuildContext context) {
    final compact = size == OrganicCardSize.half;
    final titleSize = compact ? 13.0 : 15.0;
    final metaSize = compact ? 7.5 : 8.5;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: FeedCardTapScale(
        onTap: onTap,
        child: SizedBox(
          height: _height,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: PeeplHomeTokens.organicSeparator,
                  width: PeeplHomeTokens.organicCardBorderWidth,
                ),
              ),
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FeedCardImage(source: imageUrl),
                  Positioned.fill(
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
                          stops: [0.0, 0.45, 1.0],
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
                              compact ? 8 : 12,
                              compact ? 5 : 6,
                              compact ? 8 : 12,
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
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    letterSpacing: -0.2,
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
                                              .withValues(alpha: 0.58),
                                          fontSize: metaSize,
                                          fontWeight: FontWeight.w400,
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
                                          color: Colors.orange.shade300
                                              .withValues(alpha: 0.82),
                                          fontSize: metaSize,
                                          fontWeight: FontWeight.w400,
                                          height: 1.0,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: compact ? 6 : 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.chevron_right,
                              color: PeeplHomeTokens.white.withValues(alpha: 0.82),
                              size: compact ? 16 : 18,
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
