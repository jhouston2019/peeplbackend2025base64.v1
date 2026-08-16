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
    required this.crowdData,
    required this.onTap,
    this.name,
    this.nameWidget,
    this.subtitleLabel,
    this.size = OrganicCardSize.featured,
    this.marginHorizontal,
    this.onShare,
  }) : assert(name != null || nameWidget != null,
            'Provide either name or nameWidget');

  final String imageUrl;
  final String? name;
  final Widget? nameWidget;
  final CrowdDisplayData crowdData;
  final VoidCallback onTap;
  final String? subtitleLabel;
  final OrganicCardSize size;
  final double? marginHorizontal;
  final VoidCallback? onShare;

  static const _navyOverlay = Color(0xFF050F19);

  double _height(BuildContext context) => size == OrganicCardSize.featured
      ? PeeplHomeTokens.featuredCardHeightFor(context)
      : PeeplHomeTokens.halfCardHeightFor(context);

  double get _horizontalMargin =>
      marginHorizontal ?? PeeplHomeTokens.cardHorizontalMargin;

  double get _crowdEdgeInset =>
      size == OrganicCardSize.half ? 6.0 : 8.0;

  @override
  Widget build(BuildContext context) {
    final compact = size == OrganicCardSize.half;
    final titleSize = compact ? 15.0 : 16.0;
    final metaSize = compact ? 11.0 : 12.0;
    final horizontalPadding = compact ? 10.0 : 14.0;
    final nameMaxLines = compact ? 1 : 2;
    final titleStyle = TextStyle(
      color: PeeplHomeTokens.white,
      fontSize: titleSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -0.2,
    );
    final titleWidget = nameWidget ??
        Text(
          name!,
          maxLines: nameMaxLines,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        );

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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _navyOverlay.withValues(alpha: 0.14),
                            _navyOverlay.withValues(alpha: 0.0),
                            _navyOverlay.withValues(alpha: 0.0),
                            _navyOverlay.withValues(alpha: 0.20),
                            _navyOverlay.withValues(alpha: 0.56),
                            _navyOverlay.withValues(alpha: 0.70),
                          ],
                          stops: const [0.0, 0.24, 0.52, 0.72, 0.88, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (onShare != null)
                    Positioned(
                      top: compact ? 8 : 10,
                      right: compact ? 8 : 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onShare,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 6 : 8),
                            child: Icon(
                              Icons.ios_share_rounded,
                              color: PeeplHomeTokens.white,
                              size: compact ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: _crowdEdgeInset,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleWidget,
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
                        CrowdStatusPanel(
                          data: crowdData,
                          compact: compact,
                          showTrend: false,
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
