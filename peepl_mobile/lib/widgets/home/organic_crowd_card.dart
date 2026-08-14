import 'package:flutter/material.dart';

import '../../utils/crowd_display_mapper.dart';
import '../crowd_meter.dart';
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
    this.subtitleLabel,
    this.size = OrganicCardSize.featured,
    this.marginHorizontal,
  });

  final String imageUrl;
  final String name;
  final CrowdDisplayData crowdData;
  final VoidCallback onTap;
  final String? subtitleLabel;
  final OrganicCardSize size;
  final double? marginHorizontal;

  double _height(BuildContext context) => size == OrganicCardSize.featured
      ? PeeplHomeTokens.featuredCardHeightFor(context)
      : PeeplHomeTokens.halfCardHeightFor(context);

  double get _horizontalMargin =>
      marginHorizontal ?? PeeplHomeTokens.cardHorizontalMargin;

  @override
  Widget build(BuildContext context) {
    final compact = size == OrganicCardSize.half;
    final titleSize = compact ? 14.0 : 15.0;
    final metaSize = compact ? 10.0 : 11.0;
    final horizontalPadding = compact ? 10.0 : 14.0;
    final meterSize = compact ? 38.0 : 44.0;
    final nameMaxLines = compact ? 1 : 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
      child: FeedCardTapScale(
        onTap: onTap,
        child: SizedBox(
          height: _height(context),
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
                            Color(0x00050F19),
                          ],
                          stops: [0.0, 0.38, 0.72],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: nameMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: PeeplHomeTokens.white,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (subtitleLabel != null &&
                                  subtitleLabel!.isNotEmpty) ...[
                                SizedBox(height: compact ? 2 : 3),
                                Text(
                                  subtitleLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PeeplHomeTokens.white
                                        .withValues(alpha: 0.7),
                                    fontSize: metaSize,
                                    fontWeight: FontWeight.w400,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        CrowdMeter(
                          level: crowdData.score,
                          size: meterSize,
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
