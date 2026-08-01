import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'feed_card_image.dart';
import 'feed_card_tap_scale.dart';
import 'peepl_home_tokens.dart';

class SponsoredNativeCard extends StatefulWidget {
  const SponsoredNativeCard({
    super.key,
    required this.name,
    required this.tagline,
    required this.offerLine,
    required this.initial,
    required this.accentColor,
    required this.imageUrl,
    required this.ctaLabel,
    required this.onOpen,
    required this.onCta,
    this.onImpression,
    this.onViewable,
  });

  final String name;
  final String tagline;
  final String offerLine;
  final String initial;
  final Color accentColor;
  final String imageUrl;
  final String ctaLabel;
  final VoidCallback onOpen;
  final VoidCallback onCta;
  final VoidCallback? onImpression;
  final VoidCallback? onViewable;

  @override
  State<SponsoredNativeCard> createState() => _SponsoredNativeCardState();
}

class _SponsoredNativeCardState extends State<SponsoredNativeCard> {
  bool _impressionFired = false;
  bool _viewabilityFired = false;
  Timer? _viewabilityTimer;

  @override
  void dispose() {
    _viewabilityTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (widget.onImpression == null && widget.onViewable == null) return;

    if (info.visibleFraction >= 0.5) {
      if (!_impressionFired && widget.onImpression != null) {
        _impressionFired = true;
        widget.onImpression!();
      }
      if (!_viewabilityFired &&
          widget.onViewable != null &&
          _viewabilityTimer == null) {
        _viewabilityTimer = Timer(const Duration(seconds: 1), () {
          if (!mounted || _viewabilityFired) return;
          _viewabilityFired = true;
          widget.onViewable?.call();
        });
      }
    } else {
      _viewabilityTimer?.cancel();
      _viewabilityTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PeeplHomeTokens.sponsoredHorizontalMargin,
      ),
      child: Semantics(
        label: 'Sponsored advertisement for ${widget.name}',
        button: true,
        child: FeedCardTapScale(
          onTap: widget.onOpen,
          child: Container(
            height: PeeplHomeTokens.sponsoredCardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PeeplHomeTokens.cardRadius),
              border: Border.all(
                color: PeeplHomeTokens.sponsoredBorder,
                width: PeeplHomeTokens.sponsoredBorderWidth,
              ),
              boxShadow: const [
                PeeplHomeTokens.sponsoredGlowEdge,
                PeeplHomeTokens.sponsoredGlowDrop,
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.imageUrl.isNotEmpty)
                  FeedCardImage(source: widget.imageUrl)
                else
                  ColoredBox(color: widget.accentColor.withValues(alpha: 0.35)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.78),
                          Colors.black.withValues(alpha: 0.42),
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SponsoredBadge(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _LogoTile(
                            initial: widget.initial,
                            accentColor: widget.accentColor,
                            imageUrl: widget.imageUrl,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PeeplHomeTokens.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                if (widget.offerLine.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.offerLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: PeeplHomeTokens.dealsYellow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                if (widget.tagline.isNotEmpty &&
                                    widget.tagline != widget.offerLine) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.tagline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: PeeplHomeTokens.white
                                          .withValues(alpha: 0.78),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: widget.ctaLabel,
                            button: true,
                            child: GestureDetector(
                              onTap: widget.onCta,
                              behavior: HitTestBehavior.opaque,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 36,
                                  minWidth: 36,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PeeplHomeTokens.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.ctaLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF111111),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 14,
                                        color: Color(0xFF111111),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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

    if (widget.onImpression == null && widget.onViewable == null) {
      return card;
    }

    return VisibilityDetector(
      key: Key('sponsored_${widget.name}_${widget.ctaLabel.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: card,
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '★ SPONSORED',
        style: TextStyle(
          color: PeeplHomeTokens.white.withValues(alpha: 0.92),
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          height: 1.0,
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.initial,
    required this.accentColor,
    required this.imageUrl,
  });

  final String initial;
  final Color accentColor;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.startsWith('assets/')
          ? Image.asset(imageUrl, fit: BoxFit.contain)
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: PeeplHomeTokens.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}
