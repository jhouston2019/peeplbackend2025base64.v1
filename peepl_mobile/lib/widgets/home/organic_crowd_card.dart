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
    this.onLongPress,
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
  final void Function(Rect shareOrigin)? onShare;
  final VoidCallback? onLongPress;

  static TextStyle titleStyle({required bool compact}) {
    return TextStyle(
      color: PeeplHomeTokens.organicVenueName,
      fontSize: compact ? 16.0 : 17.0,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -0.2,
      shadows: [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: compact ? 6.0 : 7.0,
          color: Colors.black.withValues(alpha: 0.75),
        ),
        Shadow(
          offset: const Offset(0, 2),
          blurRadius: compact ? 10.0 : 12.0,
          color: Colors.black.withValues(alpha: 0.45),
        ),
      ],
    );
  }

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
    final metaSize = compact ? 11.0 : 12.0;
    final horizontalPadding = compact ? 10.0 : 14.0;
    final nameMaxLines = compact ? 1 : 2;
    final titleWidget = nameWidget ??
        Text(
          name!,
          maxLines: nameMaxLines,
          overflow: TextOverflow.ellipsis,
          style: OrganicCrowdCard.titleStyle(compact: compact),
        );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalMargin),
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
                FeedCardTapScale(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FeedCardImage(source: imageUrl),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
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
                            SizedBox(width: compact ? 52 : 58),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: _crowdEdgeInset,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CrowdStatusPanel(
                            data: crowdData,
                            compact: compact,
                            showTrend: false,
                          ),
                          if (onShare != null) ...[
                            SizedBox(height: compact ? 4 : 6),
                            _ShareLabel(
                              compact: compact,
                              onTap: onShare!,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareLabel extends StatelessWidget {
  const _ShareLabel({
    required this.compact,
    required this.onTap,
  });

  final bool compact;
  final ValueChanged<Rect> onTap;

  static const _shadows = [
    Shadow(
      offset: Offset.zero,
      blurRadius: 6,
      color: Color(0x99000000),
    ),
    Shadow(
      offset: Offset(0, 1),
      blurRadius: 3,
      color: Color(0xE6000000),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100);
        onTap(origin);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 2 : 3,
        ),
        child: Text(
          'Share',
          style: TextStyle(
            color: PeeplHomeTokens.white.withValues(alpha: 0.92),
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: 0.2,
            shadows: _shadows,
          ),
        ),
      ),
    );
  }
}
